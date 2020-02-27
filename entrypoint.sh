#!/bin/bash

export RUNNER_ALLOW_RUNASROOT=1
export PATH=$PATH:/actions-runner

_RUNNER_NAME=${RUNNER_NAME:-default}
_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work}

if [[ -n "${ACCESS_TOKEN}" ]]; then
    URI=https://api.github.com
    API_VERSION=v3
    API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"
    AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"

    _PROTO="$(echo "${REPO_URL}" | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    _URL="$(echo "${REPO_URL/${_PROTO}/}")"
    _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    _REPO="$(echo "${_PATH}" | cut -d/ -f2)"

    RUNNER_TOKEN="$(curl -XPOST -fsSL \
    -H "${AUTH_HEADER}" \
    -H "${API_HEADER}" \
    "${URI}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token" \
    | jq -r '.token')"
fi

./config.sh --url "${REPO_URL}" --token "${RUNNER_TOKEN}" --name "${_RUNNER_NAME}" --work "${_RUNNER_WORKDIR}"
./run.sh
