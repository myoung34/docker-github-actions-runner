#!/bin/bash

set -o pipefail
source /common.sh || { echo -e "ERROR: failed to import /common.sh"; exit 1; }

API_HEADER="Accept: application/vnd.github.${GH_API_VER}+json"
AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"
CONTENT_LENGTH_HEADER="Content-Length: 0"

case ${RUNNER_SCOPE} in
  org)
    # https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-an-organization
    _FULL_URL="${GH_API_ROOT}/orgs/${ORG_NAME}/actions/runners/registration-token"
    ;;
  enterprise)
    _FULL_URL="${GH_API_ROOT}/enterprises/${ENTERPRISE_NAME}/actions/runners/registration-token"
    ;;
  repo)
    _PROTO='https://'
    # shellcheck disable=SC2116
    _URL="$(echo "${REPO_URL/${_PROTO}/}")"
    _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    _REPO="$(echo "${_PATH}" | cut -d/ -f2)"
    # https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-a-repository
    _FULL_URL="${GH_API_ROOT}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token"
    ;;
  *) fail "unexpected runner scope [$RUNNER_SCOPE] -- report this issue to project upstream" ;;
esac

RUNNER_TOKEN="$(curl -XPOST -fsSL \
  -H "${CONTENT_LENGTH_HEADER}" \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  "${_FULL_URL}" | jq -re .token)" || fail "$_FULL_URL fetch & [.token] extraction failed with $?"

printf '{"token": "%s", "full_url": "%s"}' "$RUNNER_TOKEN" "$_FULL_URL"
