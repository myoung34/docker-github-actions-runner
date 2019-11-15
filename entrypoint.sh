#!/bin/bash
export AGENT_ALLOW_RUNASROOT=1
echo ${RUNNER_NAME:-default}$'\n\n' | /config.sh --url ${REPO_URL} --token ${RUNNER_TOKEN}
exec /run.sh
