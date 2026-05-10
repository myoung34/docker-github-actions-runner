#!/usr/bin/dumb-init /bin/bash
# shellcheck shell=bash

export RUNNER_ALLOW_RUNASROOT=1
export PATH=${PATH}:/actions-runner

# Un-export these, so that they must be passed explicitly to the environment of
# any command that needs them.  This may help prevent leaks.
export -n ACCESS_TOKEN
export -n RUNNER_TOKEN
export -n APP_ID
export -n APP_PRIVATE_KEY

trap_with_arg() {
    func="$1" ; shift
    for sig ; do
        # shellcheck disable=SC2064
        trap "$func $sig" "$sig"
    done
}

deregister_runner() {
  echo "Caught $1 - Deregistering runner"
  if [[ -n "${ACCESS_TOKEN}" ]]; then
    # If using GitHub App authentication, refresh the access token before deregistration
    if [[ -n "${APP_ID}" ]] && [[ -n "${APP_PRIVATE_KEY}" ]] && [[ -n "${APP_LOGIN}" ]]; then
      echo "Refreshing access token for deregistration"
      nl="
"
      NEW_ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY//\\n/${nl}}" APP_LOGIN="${APP_LOGIN}" bash /app_token.sh)
      if [[ -z "${NEW_ACCESS_TOKEN}" ]] || [[ "${NEW_ACCESS_TOKEN}" == "null" ]]; then
        echo "ERROR: Failed to refresh access token for deregistration"
        exit 1
      fi
      ACCESS_TOKEN="${NEW_ACCESS_TOKEN}"
      echo "Access token refreshed successfully"
    fi
    _TOKEN=$(ACCESS_TOKEN="${ACCESS_TOKEN}" bash /token.sh)
    RUNNER_TOKEN=$(echo "${_TOKEN}" | jq -r .token)
  fi
  ./config.sh remove --token "${RUNNER_TOKEN}"
  [[ -f "/actions-runner/.runner" ]] && rm -f /actions-runner/.runner
  exit
}

_DEBUG_ONLY=${DEBUG_ONLY:-false}
_DEBUG_OUTPUT=${DEBUG_OUTPUT:-false}
_DISABLE_AUTOMATIC_DEREGISTRATION=${DISABLE_AUTOMATIC_DEREGISTRATION:-false}

_RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:="true"}

_RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}
if [[ ${RANDOM_RUNNER_SUFFIX} != "true" ]]; then
  # In some cases this file does not exist
  if [[ -f "/etc/hostname" ]]; then
    # in some cases it can also be empty
    if [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
      _RUNNER_NAME_PREFIX=${RUNNER_NAME_PREFIX-"github-runner"}
      _RUNNER_NAME=${RUNNER_NAME:-${_RUNNER_NAME_PREFIX:+${_RUNNER_NAME_PREFIX}-}$(cat /etc/hostname)}
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${_RUNNER_NAME}"
    else
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} ./etc/hostname exists but is empty. Not using /etc/hostname."
    fi
  else
    echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname does not exist. Not using /etc/hostname."
  fi
fi

_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work/${_RUNNER_NAME}}
_LABELS=${RUNNER_LABELS:-${LABELS:-default}}
_RUNNER_GROUP=${RUNNER_GROUP:-Default}
_GITHUB_HOST=${GITHUB_HOST:="github.com"}
_RUN_AS_ROOT=${RUN_AS_ROOT:="true"}
_START_DOCKER_SERVICE=${START_DOCKER_SERVICE:="false"}
_UNSET_CONFIG_VARS=${UNSET_CONFIG_VARS:="false"}
_CONFIGURED_ACTIONS_RUNNER_FILES_DIR=${CONFIGURED_ACTIONS_RUNNER_FILES_DIR:-""}

# ============================================================
# Multi-repo mode
# REPO_URLS=url1,url2,... runs N runners in this single
# container, one per repo. RUNNER_SCOPE is forced to "repo".
# When REPO_URLS is empty the single-repo flow below runs
# unchanged (full backwards compat).
# ============================================================
_REPO_URLS=${REPO_URLS:-""}
if [[ -n "${_REPO_URLS}" ]]; then
  if [[ -n "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
    echo "ERROR: CONFIGURED_ACTIONS_RUNNER_FILES_DIR is incompatible with REPO_URLS (multi-repo mode)" >&2
    exit 1
  fi

  IFS=',' read -ra _REPO_ARRAY <<< "${_REPO_URLS}"
  if [[ ${#_REPO_ARRAY[@]} -eq 0 ]]; then
    echo "ERROR: REPO_URLS is set but contains no URLs" >&2
    exit 1
  fi

  if [[ -n "${APP_ID}" ]] && [[ -z "${APP_LOGIN}" ]]; then
    _first_url="${_REPO_ARRAY[0]// /}"
    APP_LOGIN=${_first_url%/*}
    APP_LOGIN=${APP_LOGIN##*/}
  fi

  if [[ -n "${APP_ID}" ]] && [[ -n "${APP_PRIVATE_KEY}" ]] && [[ -n "${APP_LOGIN}" ]]; then
    if [[ -n "${ACCESS_TOKEN}" ]] || [[ -n "${RUNNER_TOKEN}" ]]; then
      echo "ERROR: ACCESS_TOKEN or RUNNER_TOKEN provided but mutually exclusive with APP_ID, APP_PRIVATE_KEY and APP_LOGIN." >&2
      exit 1
    fi
    echo "Obtaining access token for app_id ${APP_ID} and login ${APP_LOGIN}"
    nl="
"
    ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY//\\n/${nl}}" APP_LOGIN="${APP_LOGIN}" bash /app_token.sh)
  elif [[ -n "${APP_ID}" ]] || [[ -n "${APP_PRIVATE_KEY}" ]] || [[ -n "${APP_LOGIN}" ]]; then
    echo "ERROR: All of APP_ID, APP_PRIVATE_KEY and APP_LOGIN must be specified." >&2
    exit 1
  fi

  if [[ -z "${ACCESS_TOKEN}" ]] && [[ -z "${RUNNER_TOKEN}" ]]; then
    echo "ERROR: ACCESS_TOKEN (or APP_ID/APP_PRIVATE_KEY/APP_LOGIN) required for multi-repo mode" >&2
    exit 1
  fi
  if [[ -n "${RUNNER_TOKEN}" ]] && [[ ${#_REPO_ARRAY[@]} -gt 1 ]]; then
    echo "ERROR: RUNNER_TOKEN is per-repo and cannot be shared across multiple REPO_URLS. Use ACCESS_TOKEN." >&2
    exit 1
  fi

  declare -a _MULTI_URLS=()
  declare -a _MULTI_DIRS=()
  declare -a _MULTI_NAMES=()
  declare -a _MULTI_WORKDIRS=()

  for _i in "${!_REPO_ARRAY[@]}"; do
    _repo_url="${_REPO_ARRAY[$_i]// /}"
    [[ -z "${_repo_url}" ]] && continue

    _idx=$((_i + 1))
    _runner_dir="/actions-runner-${_idx}"
    _repo_short="${_repo_url##*/}"
    if [[ ${_RANDOM_RUNNER_SUFFIX} != "true" ]] \
       && [[ -f "/etc/hostname" ]] \
       && [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
      _suffix="$(cat /etc/hostname)"
    else
      _suffix="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 ; echo '')"
    fi
    _runner_name="${RUNNER_NAME_PREFIX:-github-runner}-${_repo_short}-${_suffix}"
    _wd="${RUNNER_WORKDIR:-/_work}/${_runner_name}"

    if [[ ! -d "${_runner_dir}" ]]; then
      echo "Preparing ${_runner_dir} (hardlink from /actions-runner)"
      cp -al /actions-runner "${_runner_dir}" 2>/dev/null || cp -r /actions-runner "${_runner_dir}"
    fi
    [[ -f "${_runner_dir}/.runner" ]] && rm -f "${_runner_dir}/.runner"

    _MULTI_URLS+=("${_repo_url}")
    _MULTI_DIRS+=("${_runner_dir}")
    _MULTI_NAMES+=("${_runner_name}")
    _MULTI_WORKDIRS+=("${_wd}")
  done

  if [[ ${_DEBUG_ONLY} == "false" ]]; then
    for _i in "${!_MULTI_URLS[@]}"; do
      _repo_url="${_MULTI_URLS[$_i]}"
      _runner_dir="${_MULTI_DIRS[$_i]}"
      _runner_name="${_MULTI_NAMES[$_i]}"
      _wd="${_MULTI_WORKDIRS[$_i]}"

      if [[ -n "${ACCESS_TOKEN}" ]]; then
        echo "Obtaining registration token for ${_repo_url}"
        _T=$(REPO_URL="${_repo_url}" RUNNER_SCOPE=repo ACCESS_TOKEN="${ACCESS_TOKEN}" bash /token.sh)
        _RT=$(echo "${_T}" | jq -r .token)
      else
        _RT="${RUNNER_TOKEN}"
      fi

      ARGS=()
      # shellcheck disable=SC2153
      [[ -n "${EPHEMERAL}" ]] && ARGS+=("--ephemeral")
      [[ -n "${DISABLE_AUTO_UPDATE}" ]] && ARGS+=("--disableupdate")
      [[ -n "${NO_DEFAULT_LABELS}" ]] && ARGS+=("--no-default-labels")

      echo "Configuring ${_runner_name} in ${_runner_dir}"
      pushd "${_runner_dir}" > /dev/null
      ./config.sh \
          --url "${_repo_url}" \
          --token "${_RT}" \
          --name "${_runner_name}" \
          --work "${_wd}" \
          --labels "${_LABELS}" \
          --runnergroup "${_RUNNER_GROUP}" \
          --unattended \
          --replace \
          "${ARGS[@]}"
      popd > /dev/null
      [[ ! -d "${_wd}" ]] && mkdir -p "${_wd}"
    done
  fi

  deregister_all() {
    echo "Caught $1 - Deregistering all runners"
    if [[ -n "${ACCESS_TOKEN}" ]]; then
      if [[ -n "${APP_ID}" ]] && [[ -n "${APP_PRIVATE_KEY}" ]] && [[ -n "${APP_LOGIN}" ]]; then
        echo "Refreshing access token for deregistration"
        nl="
"
        NEW_ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY//\\n/${nl}}" APP_LOGIN="${APP_LOGIN}" bash /app_token.sh)
        if [[ -n "${NEW_ACCESS_TOKEN}" ]] && [[ "${NEW_ACCESS_TOKEN}" != "null" ]]; then
          ACCESS_TOKEN="${NEW_ACCESS_TOKEN}"
        fi
      fi
      for _j in "${!_MULTI_URLS[@]}"; do
        _T=$(REPO_URL="${_MULTI_URLS[$_j]}" RUNNER_SCOPE=repo ACCESS_TOKEN="${ACCESS_TOKEN}" bash /token.sh)
        _RT=$(echo "${_T}" | jq -r .token)
        echo "Deregistering ${_MULTI_NAMES[$_j]} from ${_MULTI_URLS[$_j]}"
        pushd "${_MULTI_DIRS[$_j]}" > /dev/null
        ./config.sh remove --token "${_RT}" || true
        [[ -f .runner ]] && rm -f .runner
        popd > /dev/null
      done
    fi
    exit
  }

  if [[ ${_DISABLE_AUTOMATIC_DEREGISTRATION} == "false" ]] && [[ ${_DEBUG_ONLY} == "false" ]]; then
    trap_with_arg deregister_all SIGINT SIGQUIT SIGTERM INT TERM QUIT
  fi

  if [[ ${_START_DOCKER_SERVICE} == "true" ]]; then
    echo "Starting docker service"
    _PREFIX=""
    [[ ${_RUN_AS_ROOT} != "true" ]] && _PREFIX="sudo"
    if [[ ${_DEBUG_ONLY} == "true" ]]; then
      echo ${_PREFIX} service docker start
    else
      ${_PREFIX} service docker start
    fi
  fi

  if [[ ${_UNSET_CONFIG_VARS} == "true" ]]; then
    echo "Unsetting configuration environment variables"
    unset RUN_AS_ROOT RUNNER_NAME RUNNER_NAME_PREFIX RANDOM_RUNNER_SUFFIX
    unset ACCESS_TOKEN APP_ID APP_PRIVATE_KEY APP_LOGIN
    unset RUNNER_SCOPE ORG_NAME ENTERPRISE_NAME LABELS
    unset REPO_URL REPO_URLS RUNNER_TOKEN RUNNER_WORKDIR RUNNER_GROUP
    unset GITHUB_HOST DISABLE_AUTOMATIC_DEREGISTRATION CONFIGURED_ACTIONS_RUNNER_FILES_DIR
    unset EPHEMERAL DISABLE_AUTO_UPDATE START_DOCKER_SERVICE NO_DEFAULT_LABELS
    unset UNSET_CONFIG_VARS
  fi

  if [[ ${_DEBUG_ONLY} == "true" ]] || [[ ${_DEBUG_OUTPUT} == "true" ]] ; then
    echo ""
    echo "Multi-repo mode: ${#_MULTI_URLS[@]} runner(s)"
    echo "Disable automatic registration: ${_DISABLE_AUTOMATIC_DEREGISTRATION}"
    echo "Random runner suffix: ${_RANDOM_RUNNER_SUFFIX}"
    echo "Labels: ${_LABELS}"
    echo "Runner Group: ${_RUNNER_GROUP}"
    echo "Github Host: ${_GITHUB_HOST}"
    echo "Run as root:${_RUN_AS_ROOT}"
    echo "Start docker: ${_START_DOCKER_SERVICE}"
    for _i in "${!_MULTI_URLS[@]}"; do
      echo ""
      echo "Runner $((_i + 1))/${#_MULTI_URLS[@]}:"
      echo "  Repo URL: ${_MULTI_URLS[$_i]}"
      echo "  Runner name: ${_MULTI_NAMES[$_i]}"
      echo "  Runner dir: ${_MULTI_DIRS[$_i]}"
      echo "  Runner workdir: ${_MULTI_WORKDIRS[$_i]}"
    done
  fi

  if [[ ${_DEBUG_ONLY} == "true" ]]; then
    exit 0
  fi

  if [[ ${_RUN_AS_ROOT} == "true" ]]; then
    if [[ $(id -u) -ne 0 ]]; then
      echo "ERROR: RUN_AS_ROOT env var is set to true but the user has been overridden and is not running as root, but UID '$(id -u)'"
      exit 1
    fi
  else
    if [[ $(id -u) -eq 0 ]]; then
      chown runner /opt/hostedtoolcache/
      for _runner_dir in "${_MULTI_DIRS[@]}"; do
        chown runner "${_runner_dir}"
        find "${_runner_dir}" -mindepth 1 -maxdepth 1 ! -name bin ! -name externals -exec chown -R runner {} + 2>/dev/null || true
      done
      for _wd in "${_MULTI_WORKDIRS[@]}"; do
        chown runner "${_wd}"
      done
    fi
  fi

  declare -a _MULTI_PIDS=()
  for _i in "${!_MULTI_DIRS[@]}"; do
    _runner_dir="${_MULTI_DIRS[$_i]}"
    if [[ ${_RUN_AS_ROOT} == "true" ]]; then
      ( cd "${_runner_dir}" && exec ./bin/Runner.Listener run --startuptype service ) &
    elif [[ $(id -u) -eq 0 ]]; then
      ( cd "${_runner_dir}" && exec /usr/sbin/gosu runner ./bin/Runner.Listener run --startuptype service ) &
    else
      ( cd "${_runner_dir}" && exec ./bin/Runner.Listener run --startuptype service ) &
    fi
    _MULTI_PIDS+=($!)
    echo "Started ${_MULTI_NAMES[$_i]} (PID $!) in ${_runner_dir}"
  done

  wait "${_MULTI_PIDS[@]}"
  exit $?
fi

# ensure backwards compatibility
if [[ -z ${RUNNER_SCOPE} ]]; then
  if [[ ${ORG_RUNNER} == "true" ]]; then
    echo 'ORG_RUNNER is now deprecated. Please use RUNNER_SCOPE="org" instead.'
    export RUNNER_SCOPE="org"
  else
    export RUNNER_SCOPE="repo"
  fi
fi

RUNNER_SCOPE="${RUNNER_SCOPE,,}" # to lowercase

case ${RUNNER_SCOPE} in
  org*)
    [[ -z ${ORG_NAME} ]] && ( echo "ORG_NAME required for org runners"; exit 1 )
    _SHORT_URL="https://${_GITHUB_HOST}/${ORG_NAME}"
    RUNNER_SCOPE="org"
    if [[ -n "${APP_ID}" ]] && [[ -z "${APP_LOGIN}" ]]; then
      APP_LOGIN=${ORG_NAME}
    fi
    ;;

  ent*)
    [[ -z ${ENTERPRISE_NAME} ]] && ( echo "ENTERPRISE_NAME required for enterprise runners"; exit 1 )
    _SHORT_URL="https://${_GITHUB_HOST}/enterprises/${ENTERPRISE_NAME}"
    RUNNER_SCOPE="enterprise"
    ;;

  *)
    [[ -z ${REPO_URL} ]] && ( echo "REPO_URL required for repo runners"; exit 1 )
    _SHORT_URL=${REPO_URL}
    RUNNER_SCOPE="repo"
    if [[ -n "${APP_ID}" ]] && [[ -z "${APP_LOGIN}" ]]; then
      APP_LOGIN=${REPO_URL%/*}
      APP_LOGIN=${APP_LOGIN##*/}
    fi
    ;;
esac

configure_runner() {
  ARGS=()
  if [[ -n "${APP_ID}" ]] && [[ -n "${APP_PRIVATE_KEY}" ]] && [[ -n "${APP_LOGIN}" ]]; then
    if [[ -n "${ACCESS_TOKEN}" ]] || [[ -n "${RUNNER_TOKEN}" ]]; then
      echo "ERROR: ACCESS_TOKEN or RUNNER_TOKEN provided but are mutually exclusive with APP_ID, APP_PRIVATE_KEY and APP_LOGIN." >&2
      exit 1
    fi
    echo "Obtaining access token for app_id ${APP_ID} and login ${APP_LOGIN}"
    nl="
"
    ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY//\\n/${nl}}" APP_LOGIN="${APP_LOGIN}" bash /app_token.sh)
  elif [[ -n "${APP_ID}" ]] || [[ -n "${APP_PRIVATE_KEY}" ]] || [[ -n "${APP_LOGIN}" ]]; then
    echo "ERROR: All of APP_ID, APP_PRIVATE_KEY and APP_LOGIN must be specified." >&2
    exit 1
  fi

  if [[ -n "${ACCESS_TOKEN}" ]]; then
    echo "Obtaining the token of the runner"
    _TOKEN=$(ACCESS_TOKEN="${ACCESS_TOKEN}" bash /token.sh)
    RUNNER_TOKEN=$(echo "${_TOKEN}" | jq -r .token)
  fi

  # shellcheck disable=SC2153
  if [ -n "${EPHEMERAL}" ]; then
    echo "Ephemeral option is enabled"
    ARGS+=("--ephemeral")
  fi

  if [ -n "${DISABLE_AUTO_UPDATE}" ]; then
    echo "Disable auto update option is enabled"
    ARGS+=("--disableupdate")
  fi

  if [ -n "${NO_DEFAULT_LABELS}" ]; then
    echo "Disable adding the default self-hosted, platform, and architecture labels"
    ARGS+=("--no-default-labels")
  fi

  echo "Configuring"
  ./config.sh \
      --url "${_SHORT_URL}" \
      --token "${RUNNER_TOKEN}" \
      --name "${_RUNNER_NAME}" \
      --work "${_RUNNER_WORKDIR}" \
      --labels "${_LABELS}" \
      --runnergroup "${_RUNNER_GROUP}" \
      --unattended \
      --replace \
      "${ARGS[@]}"

  [[ ! -d "${_RUNNER_WORKDIR}" ]] && mkdir -p "${_RUNNER_WORKDIR}"

}

unset_config_vars() {
  echo "Unsetting configuration environment variables"
  unset RUN_AS_ROOT
  unset RUNNER_NAME
  unset RUNNER_NAME_PREFIX
  unset RANDOM_RUNNER_SUFFIX
  unset ACCESS_TOKEN
  unset APP_ID
  unset APP_PRIVATE_KEY
  unset APP_LOGIN
  unset RUNNER_SCOPE
  unset ORG_NAME
  unset ENTERPRISE_NAME
  unset LABELS
  unset REPO_URL
  unset REPO_URLS
  unset RUNNER_TOKEN
  unset RUNNER_WORKDIR
  unset RUNNER_GROUP
  unset GITHUB_HOST
  unset DISABLE_AUTOMATIC_DEREGISTRATION
  unset CONFIGURED_ACTIONS_RUNNER_FILES_DIR
  unset EPHEMERAL
  unset DISABLE_AUTO_UPDATE
  unset START_DOCKER_SERVICE
  unset NO_DEFAULT_LABELS
  unset UNSET_CONFIG_VARS
}

# Opt into runner reusage because a value was given
if [[ -n "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
  echo "Runner reusage is enabled"

  # directory exists, copy the data
  if [[ -d "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
    echo "Copying previous data"
    cp -p -r "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}/." "/actions-runner"
  fi

  if [ -f "/actions-runner/.runner" ]; then
    echo "The runner has already been configured"
  else

    if [[ ${_DEBUG_ONLY} == "false" ]]; then
      configure_runner
    fi
  fi
else
  echo "Runner reusage is disabled"
  if [[ ${_DEBUG_ONLY} == "false" ]]; then
    [[ -f "/actions-runner/.runner" ]] && rm -f /actions-runner/.runner
    configure_runner
  fi
fi

if [[ -n "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
  echo "Reusage is enabled. Storing data to ${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
  if [[ ${_DISABLE_AUTOMATIC_DEREGISTRATION} == "false" ]]; then
    echo "DISABLE_AUTOMATIC_DEREGISTRATION should be set to true to avoid issues with re-using a deregistered runner."
    exit 1
  fi
  # Quoting (even with double-quotes) the regexp brokes the copying
  cp -p -r "/actions-runner/_diag" "/actions-runner/svc.sh" /actions-runner/.[^.]* "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
fi



if [[ ${_DISABLE_AUTOMATIC_DEREGISTRATION} == "false" ]]; then
  if [[ ${_DEBUG_ONLY} == "false" ]]; then
    trap_with_arg deregister_runner SIGINT SIGQUIT SIGTERM INT TERM QUIT
  fi
fi

# Start docker service if needed (e.g. for docker-in-docker)
if [[ ${_START_DOCKER_SERVICE} == "true" ]]; then
  echo "Starting docker service"
  _PREFIX=""
  [[ ${_RUN_AS_ROOT} != "true" ]] && _PREFIX="sudo"

  if [[ ${_DEBUG_ONLY} == "true" ]]; then
    echo ${_PREFIX} service docker start
  else
    ${_PREFIX} service docker start
  fi
fi

# Unset configuration environment variables if the flag is set
if [[ ${_UNSET_CONFIG_VARS} == "true" ]]; then
  unset_config_vars
fi

# Container's command (CMD) execution as runner user


if [[ ${_DEBUG_ONLY} == "true" ]] || [[ ${_DEBUG_OUTPUT} == "true" ]] ; then
  echo ""
  echo "Disable automatic registration: ${_DISABLE_AUTOMATIC_DEREGISTRATION}"
  echo "Random runner suffix: ${_RANDOM_RUNNER_SUFFIX}"
  echo "Runner name: ${_RUNNER_NAME}"
  echo "Runner workdir: ${_RUNNER_WORKDIR}"
  echo "Labels: ${_LABELS}"
  echo "Runner Group: ${_RUNNER_GROUP}"
  echo "Github Host: ${_GITHUB_HOST}"
  echo "Run as root:${_RUN_AS_ROOT}"
  echo "Start docker: ${_START_DOCKER_SERVICE}"
fi

if [[ ${_RUN_AS_ROOT} == "true" ]]; then
  if [[ $(id -u) -eq 0 ]]; then
    if [[ ${_DEBUG_ONLY} == "true" ]] || [[ ${_DEBUG_OUTPUT} == "true" ]] ; then
      # shellcheck disable=SC2145
      echo "Running $@"
    fi
    if [[ ${_DEBUG_ONLY} == "false" ]]; then
      "$@"
    fi
  else
    echo "ERROR: RUN_AS_ROOT env var is set to true but the user has been overridden and is not running as root, but UID '$(id -u)'"
    exit 1
  fi
else
  if [[ $(id -u) -eq 0 ]]; then
    [[ -n "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]] && chown -R runner "${_CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
    # /actions-runner/{bin,externals} ship runner-owned from the image
    # (~380 MB / 9k+ files). Recursing over them triggers overlay copy-up
    # per file even when ownership already matches, which dominates startup
    # under parallel runners. Only config.sh (run as root earlier) may have
    # written new root-owned files at the top level — chown those plus
    # /actions-runner itself and ${_RUNNER_WORKDIR}, but not the big dirs.
    chown runner /actions-runner "${_RUNNER_WORKDIR}"
    find /actions-runner -mindepth 1 -maxdepth 1 ! -name bin ! -name externals -exec chown -R runner {} + 2>/dev/null || true
    # The toolcache is not recursively chowned to avoid recursing over prepulated tooling in derived docker images
    chown runner /opt/hostedtoolcache/
    if [[ ${_DEBUG_ONLY} == "true" ]] || [[ ${_DEBUG_OUTPUT} == "true" ]] ; then
      # shellcheck disable=SC2145
      echo "Running /usr/sbin/gosu runner $@"
    fi
    if [[ ${_DEBUG_ONLY} == "false" ]]; then
      /usr/sbin/gosu runner "$@"
    fi
  else
    if [[ ${_DEBUG_ONLY} == "true" ]] || [[ ${_DEBUG_OUTPUT} == "true" ]] ; then
      # shellcheck disable=SC2145
      echo "Running $@"
    fi
    if [[ ${_DEBUG_ONLY} == "false" ]]; then
      "$@"
    fi
  fi
fi
