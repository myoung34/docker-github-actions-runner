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
    _URL="${REPO_URL#*://}"  # strip the protocol
    _ACCOUNT="$(cut -d/ -f2 <<< "$_URL")"
    _REPO="$(cut -d/ -f3 <<< "$_URL")"
    # https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-a-repository
    _FULL_URL="${GH_API_ROOT}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token"
    ;;
  *) fail "unexpected runner scope [$RUNNER_SCOPE] -- report this issue to project upstream" ;;
esac

curl -XPOST -fsSL \
  -H "${CONTENT_LENGTH_HEADER}" \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  "${_FULL_URL}" | jq -re .token || fail "$_FULL_URL fetch & [.token] extraction failed with $?"
