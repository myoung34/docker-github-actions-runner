#!/bin/bash
# Check jobs acceptance timeout.
# If jobs cannot be confirmed, listening will be terminated.

if [ -z "$1" ]; then exit 1; fi

_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work}
_JOBS_ACCEPTANCE_TIMEOUT=$1

while [ 1 ]; do
  if [ ! -e ${_RUNNER_WORKDIR}/_temp/_github_workflow ]; then
    _DURATION=`expr $(date +%s) - $(date +%s -r /tmp)`
    [[ $_DURATION -ge ${_JOBS_ACCEPTANCE_TIMEOUT} ]] && break
  fi
  sleep 10
done

echo $(date '+%Y-%m-%d %H:%M:%SZ:') Stop listening due to timeout.
pkill --signal=SIGINT -f ./bin/Runner.Listener
exit 0