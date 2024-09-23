#!/bin/bash

_GITHUB_HOST=${GITHUB_HOST:="github.com"}

# If URL is not github.com then use the enterprise api endpoint
if [[ ${GITHUB_HOST} = "github.com" ]]; then
  URI="https://api.${_GITHUB_HOST}"
else
  URI="https://${_GITHUB_HOST}/api/v3"
fi

API_VERSION=v3
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"
AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"

case ${RUNNER_SCOPE} in
  org*)
    _FULL_URL="${URI}/orgs/${ORG_NAME}/actions/runner-groups"
    ;;

  ent*)
    _FULL_URL="${URI}/enterprises/${ENTERPRISE_NAME}/actions/runner-groups"
    ;;

  *)
    _PROTO="https://"
    # shellcheck disable=SC2116
    _URL="$(echo "${REPO_URL/${_PROTO}/}")"
    _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    _REPO="$(echo "${_PATH}" | cut -d/ -f2)"
    _FULL_URL="${URI}/repos/${_ACCOUNT}/${_REPO}/actions/runner-groups"
    ;;
esac

echo "Creating runner group ${RUNNER_GROUP}"
# contains http return body and the status code, separated with a line break
_RETURN_CODE="$(curl -XPOST -sL \
  --write-out "%{http_code}" \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  -d "{\"name\":\"${RUNNER_GROUP}\"}" \
  "${_FULL_URL}")"

# 201 when the group was created, 409 when the group already existed
if [[ "$(echo "$_RETURN_CODE" | tail -n 1)" == "201" ]] || [[ "$(echo "$_RETURN_CODE" | tail -n 1)" == "409" ]]; then
  exit 0
else
  echo "Error: create runner group failed: $_RETURN_CODE" >&2
  exit 1
fi
