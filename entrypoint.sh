#!/bin/bash

export RUNNER_ALLOW_RUNASROOT=1
export PATH=$PATH:/actions-runner

_RUNNER_NAME=${RUNNER_NAME:-default}
_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work}
_ORG_RUNNER=${ORG_RUNNER:-false}
_LABELS=${LABELS:-default}

if [[ -n "${ACCESS_TOKEN}" ]]; then
    URI=https://api.github.com
    API_VERSION=v3
    API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"
    AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"

    _PROTO="$(echo "${REPO_URL}" | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    # shellcheck disable=SC2116
    _URL="$(echo "${REPO_URL/${_PROTO}/}")"
    _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    _REPO="$(echo "${_PATH}" | cut -d/ -f2)"

    _FULL_URI="${URI}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token"
    _SHORT_URL="${REPO_URL}"
    if [[ ${_ORG_RUNNER} == "true" ]]; then
      [[ -z ${ORG_NAME} ]] && ( echo "ORG_NAME required for org runners"; exit 1 )
      _FULL_URI="${URI}/orgs/${ORG_NAME}/actions/runners/registration-token"
      _SHORT_URL="${_PROTO}github.com/${ORG_NAME}"
    fi
    echo curl -XPOST -fsSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${_FULL_URI}"
    RUNNER_TOKEN="$(curl -XPOST -fsSL \
      -H "${AUTH_HEADER}" \
      -H "${API_HEADER}" \
      "${_FULL_URI}" \
    | jq -r '.token')"
fi

echo "Configuring"

./config.sh \
    --url "${_SHORT_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${_RUNNER_NAME}" \
    --work "${_RUNNER_WORKDIR}" \
    --labels "${_LABELS}" \
    --unattended \
    --replace

./run.sh
