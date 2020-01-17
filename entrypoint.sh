#!/bin/bash
export RUNNER_ALLOW_RUNASROOT=1
export PATH=$PATH:/actions-runner
_RUNNER_NAME=${RUNNER_NAME:-default}
_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work}
config.sh --url "${REPO_URL}" --token "${RUNNER_TOKEN}" --name "${_RUNNER_NAME}" --work "${_RUNNER_WORKDIR}"
exec run.sh
