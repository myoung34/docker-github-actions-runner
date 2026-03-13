#!/usr/bin/dumb-init /bin/bash
# shellcheck shell=bash

set -o pipefail

export RUNNER_ALLOW_RUNASROOT=1
export PATH=${PATH}:/actions-runner

# Un-export these, so that they must be passed explicitly to the environment of
# any command that needs them.  This may help prevent leaks.
export -n ACCESS_TOKEN
export -n RUNNER_TOKEN
export -n APP_ID
export -n APP_PRIVATE_KEY

source /common.sh || { echo -e "ERROR: failed to import /common.sh"; exit 1; }

deregister_runner() {
  local token

  echo "Caught $1 - Deregistering runner"
  if [[ -n "${ACCESS_TOKEN}" ]]; then
    # If using GitHub App authentication, refresh the access token before deregistration
    if [[ -n "${APP_ID}" && -n "${APP_PRIVATE_KEY}" && -n "${APP_LOGIN}" ]]; then
      echo "Refreshing access token for deregistration"
      ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY//\\n/$'\n'}" \
          APP_LOGIN="${APP_LOGIN}" bash /app_token.sh) || fail "app_token.sh failed with $?"
      if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "null" ]]; then
        fail "Failed to refresh access token for deregistration"
      fi
      echo "Access token refreshed successfully"
    fi
    token=$(ACCESS_TOKEN="${ACCESS_TOKEN}" bash /token.sh) || fail "token.sh failed with $?"
    RUNNER_TOKEN=$(jq -re .token <<< "$token") || fail "[.token] not found in token.sh output"
  fi

  ./config.sh remove --token "${RUNNER_TOKEN}"
  [[ -f "/actions-runner/.runner" ]] && rm -f /actions-runner/.runner
  exit
}

: "${DEBUG_ONLY:=false}"
: "${DEBUG_OUTPUT:=false}"
: "${DISABLE_AUTOMATIC_DEREGISTRATION:=false}"
: "${RANDOM_RUNNER_SUFFIX:=true}"

if [[ -z "$RUNNER_NAME" && ${RANDOM_RUNNER_SUFFIX} != "true" ]]; then
  if [[ -s "/etc/hostname" ]]; then
    _runner_name_prefix=${RUNNER_NAME_PREFIX-'github-runner'}
    RUNNER_NAME=${_runner_name_prefix:+${_runner_name_prefix}-}$(cat /etc/hostname)
    echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${RUNNER_NAME}"
  else
    echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname is not a non-empty file. Not using it"
  fi
fi
: "${RUNNER_NAME:=${RUNNER_NAME_PREFIX:-github-runner}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}"

: "${RUNNER_WORKDIR:=/_work/${RUNNER_NAME}}"
: "${RUNNER_GROUP:=Default}"
: "${GITHUB_HOST:=github.com}"
: "${RUN_AS_ROOT:=true}"
: "${START_DOCKER_SERVICE:=false}"
: "${UNSET_CONFIG_VARS:=false}"
: "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR:=''}"
# as to why $RUNNER_LABELS is used, see https://github.com/myoung34/docker-github-actions-runner/commit/ac80687f5e2a3a34b11a80daa6089281f186c2d5
LABELS=${RUNNER_LABELS:-${LABELS:-default}}

# ensure backwards compatibility
if [[ -z ${RUNNER_SCOPE} ]]; then
  if [[ ${ORG_RUNNER} == "true" ]]; then
    echo 'ORG_RUNNER env var is now deprecated. Please use RUNNER_SCOPE="org" instead.'
    RUNNER_SCOPE="org"
  else
    RUNNER_SCOPE="repo"
  fi
fi

RUNNER_SCOPE="${RUNNER_SCOPE,,}"  # to lowercase

case "${RUNNER_SCOPE}" in
  org*)
    [[ -z ${ORG_NAME} ]] && fail "ORG_NAME required for org runners"
    _SHORT_URL="https://${GITHUB_HOST}/${ORG_NAME}"
    RUNNER_SCOPE="org"
    if [[ -n "${APP_ID}" && -z "${APP_LOGIN}" ]]; then
      APP_LOGIN=${ORG_NAME}
    fi
    ;;

  ent*)
    [[ -z ${ENTERPRISE_NAME} ]] && fail "ENTERPRISE_NAME required for enterprise runners"
    _SHORT_URL="https://${GITHUB_HOST}/enterprises/${ENTERPRISE_NAME}"
    RUNNER_SCOPE="enterprise"
    ;;

  *)
    [[ -z ${REPO_URL} ]] && fail "REPO_URL required for repo runners"
    _SHORT_URL=${REPO_URL}
    RUNNER_SCOPE="repo"
    if [[ -n "${APP_ID}" && -z "${APP_LOGIN}" ]]; then
      APP_LOGIN=${REPO_URL%/*}
      APP_LOGIN=${APP_LOGIN##*/}
    fi
    ;;
esac

export RUNNER_SCOPE GITHUB_HOST

configure_runner() {
  local args token

  args=()
  if [[ -n "${APP_ID}" && -n "${APP_PRIVATE_KEY}" && -n "${APP_LOGIN}" ]]; then
    if [[ -n "${ACCESS_TOKEN}" || -n "${RUNNER_TOKEN}" ]]; then
      fail "ACCESS_TOKEN or RUNNER_TOKEN provided but are mutually exclusive with {APP_ID, APP_PRIVATE_KEY, APP_LOGIN}"
    fi
    echo "Obtaining access token for app_id ${APP_ID} and login ${APP_LOGIN}"
    ACCESS_TOKEN=$(APP_ID="${APP_ID}" APP_PRIVATE_KEY="${APP_PRIVATE_KEY//\\n/$'\n'}" \
        APP_LOGIN="${APP_LOGIN}" bash /app_token.sh) || fail "app_token.sh failed with $?"
  elif [[ -n "${APP_ID}" || -n "${APP_PRIVATE_KEY}" || -n "${APP_LOGIN}" ]]; then
    fail "either all or none of {APP_ID, APP_PRIVATE_KEY, APP_LOGIN} must be specified"
  fi

  if [[ -n "${ACCESS_TOKEN}" ]]; then
    echo "Obtaining the token of the runner"
    token=$(ACCESS_TOKEN="${ACCESS_TOKEN}" bash /token.sh) || fail "token.sh failed with $?"
    RUNNER_TOKEN=$(jq -re .token <<< "$token") || fail "[.token] not found in token.sh output"
  fi

  # shellcheck disable=SC2153
  if [[ -n "${EPHEMERAL}" ]]; then
    echo "Ephemeral option is enabled"
    args+=("--ephemeral")
  fi

  if [[ -n "${DISABLE_AUTO_UPDATE}" ]]; then
    echo "Disable auto update option is enabled"
    args+=("--disableupdate")
  fi

  if [[ -n "${NO_DEFAULT_LABELS}" ]]; then
    echo "Disable adding the default self-hosted, platform, and architecture labels"
    args+=("--no-default-labels")
  fi

  echo "Configuring"
  ./config.sh \
      --url "${_SHORT_URL}" \
      --token "${RUNNER_TOKEN}" \
      --name "${RUNNER_NAME}" \
      --work "${RUNNER_WORKDIR}" \
      --labels "${LABELS}" \
      --runnergroup "${RUNNER_GROUP}" \
      --unattended \
      --replace \
      "${args[@]}"

  [[ ! -d "${RUNNER_WORKDIR}" ]] && mkdir -p "${RUNNER_WORKDIR}"
}

unset_config_vars() {
  echo "Unsetting configuration environment variables"
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
  unset RUNNER_TOKEN
  unset RUNNER_GROUP
  unset GITHUB_HOST
  unset DISABLE_AUTOMATIC_DEREGISTRATION
  unset EPHEMERAL
  unset DISABLE_AUTO_UPDATE
  unset START_DOCKER_SERVICE
  unset NO_DEFAULT_LABELS
  unset UNSET_CONFIG_VARS
}

# Opt into runner reusage because a value was given
if [[ -n "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
  echo "Runner reusage is enabled"

  # directory exists, copy the data
  if [[ -d "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
    echo "Copying previous data"
    cp -pr -- "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}/." "/actions-runner"
  fi

  if [[ -f "/actions-runner/.runner" ]]; then
    echo "The runner has already been configured"
  else
    if [[ ${DEBUG_ONLY} == "false" ]]; then
      configure_runner
    fi
  fi
else
  echo "Runner reusage is disabled"
  if [[ ${DEBUG_ONLY} == "false" ]]; then
    [[ -f "/actions-runner/.runner" ]] && rm -f /actions-runner/.runner
    configure_runner
  fi
fi

if [[ -n "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]]; then
  echo "Reusage is enabled. Storing data to ${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
  if [[ ${DISABLE_AUTOMATIC_DEREGISTRATION} == "false" ]]; then
    fail "DISABLE_AUTOMATIC_DEREGISTRATION should be set to true to avoid issues with re-using a deregistered runner"
  fi
  # Quoting (even with double-quotes) the regexp brokes the copying
  cp -pr "/actions-runner/_diag" "/actions-runner/svc.sh" /actions-runner/.[^.]* "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
fi

# Start docker service if needed (e.g. for docker-in-docker)
if [[ ${START_DOCKER_SERVICE} == "true" ]]; then
  echo "Starting docker service"
  _PREFIX=''
  [[ ${RUN_AS_ROOT} != "true" ]] && _PREFIX="sudo"

  if [[ ${DEBUG_ONLY} == "true" ]]; then
    echo ${_PREFIX} service docker start
  else
    ${_PREFIX} service docker start
  fi
fi

# Container's command (CMD) execution as runner user

if [[ ${DEBUG_ONLY} == "true" || ${DEBUG_OUTPUT} == "true" ]]; then
  echo ''
  echo "Disable automatic registration: ${DISABLE_AUTOMATIC_DEREGISTRATION}"
  echo "Random runner suffix: ${RANDOM_RUNNER_SUFFIX}"
  echo "Runner name: ${RUNNER_NAME}"
  echo "Runner workdir: ${RUNNER_WORKDIR}"
  echo "Labels: ${LABELS}"
  echo "Runner Group: ${RUNNER_GROUP}"
  echo "Github Host: ${GITHUB_HOST}"
  echo "Run as root: ${RUN_AS_ROOT}"
  echo "Start docker: ${START_DOCKER_SERVICE}"
fi

if [[ ${DISABLE_AUTOMATIC_DEREGISTRATION} == "false" && ${DEBUG_ONLY} == "false" ]]; then
  trap_with_sig  deregister_runner SIGINT SIGQUIT SIGTERM INT TERM QUIT
elif [[ ${UNSET_CONFIG_VARS} == "true" ]]; then
  unset_config_vars
fi

if [[ ${RUN_AS_ROOT} == "true" ]]; then
  if [[ $(id -u) -eq 0 ]]; then
    if [[ ${DEBUG_ONLY} == "true" || ${DEBUG_OUTPUT} == "true" ]]; then
      # shellcheck disable=SC2145
      echo "Running $@"
    fi
    if [[ ${DEBUG_ONLY} == "false" ]]; then
      "$@"
    fi
  else
    fail "RUN_AS_ROOT env var is set to true but the user has been overridden and is not running as root, but UID [$(id -u)]"
  fi
else
  if [[ $(id -u) -eq 0 ]]; then
    [[ -n "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}" ]] && chown -R runner "${CONFIGURED_ACTIONS_RUNNER_FILES_DIR}"
    chown -R runner "${RUNNER_WORKDIR}" /actions-runner
    # The toolcache is not recursively chowned to avoid recursing over prepulated tooling in derived docker images
    chown runner /opt/hostedtoolcache/
    if [[ ${DEBUG_ONLY} == "true" || ${DEBUG_OUTPUT} == "true" ]]; then
      # shellcheck disable=SC2145
      echo "Running /usr/sbin/gosu runner $@"
    fi
    if [[ ${DEBUG_ONLY} == "false" ]]; then
      /usr/sbin/gosu runner "$@"
    fi
  else
    if [[ ${DEBUG_ONLY} == "true" || ${DEBUG_OUTPUT} == "true" ]]; then
      # shellcheck disable=SC2145
      echo "Running $@"
    fi
    if [[ ${DEBUG_ONLY} == "false" ]]; then
      "$@"
    fi
  fi
fi
