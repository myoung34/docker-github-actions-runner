#!/bin/bash

normalize_host() {
  local host="${1#http://}"
  host="${host#https://}"
  echo "${host%%/}"
}

_GITHUB_HOST=$(normalize_host "${GITHUB_HOST:="github.com"}")

if [[ -n ${GITHUB_API_HOST} ]]; then
  _GITHUB_API_HOST=$(normalize_host "${GITHUB_API_HOST}")
  _GITHUB_API_V3=${GITHUB_API_V3:-false}
elif [[ ${_GITHUB_HOST} = "github.com" ]]; then
  _GITHUB_API_HOST="api.${_GITHUB_HOST}"
  _GITHUB_API_V3=${GITHUB_API_V3:-false}
else
  _GITHUB_API_HOST="${_GITHUB_HOST}"
  _GITHUB_API_V3=${GITHUB_API_V3:-true}
fi

URI="https://${_GITHUB_API_HOST}"
if [[ ${_GITHUB_API_V3} == "true" ]]; then
  URI="${URI}/api/v3"
fi

API_VERSION=v3
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json"
AUTH_HEADER="Authorization: token ${ACCESS_TOKEN}"
CONTENT_LENGTH_HEADER="Content-Length: 0"

case ${RUNNER_SCOPE} in
  org*)
    _FULL_URL="${URI}/orgs/${ORG_NAME}/actions/runners/registration-token"
    ;;

  ent*)
    _FULL_URL="${URI}/enterprises/${ENTERPRISE_NAME}/actions/runners/registration-token"
    ;;

  *)
    _PROTO="https://"
    # shellcheck disable=SC2116
    _URL="$(echo "${REPO_URL/${_PROTO}/}")"
    _PATH="$(echo "${_URL}" | grep / | cut -d/ -f2-)"
    _ACCOUNT="$(echo "${_PATH}" | cut -d/ -f1)"
    _REPO="$(echo "${_PATH}" | cut -d/ -f2)"
    _FULL_URL="${URI}/repos/${_ACCOUNT}/${_REPO}/actions/runners/registration-token"
    ;;
esac

RUNNER_TOKEN="$(curl -XPOST -fsSL \
  -H "${CONTENT_LENGTH_HEADER}" \
  -H "${AUTH_HEADER}" \
  -H "${API_HEADER}" \
  "${_FULL_URL}" \
| jq -r '.token')"

echo "{\"token\": \"${RUNNER_TOKEN}\", \"full_url\": \"${_FULL_URL}\"}"
