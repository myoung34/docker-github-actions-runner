#!/bin/bash
# Check jobs acceptance timeout.
# If jobs cannot be confirmed, listening will be terminated.

if [ -z "$1" ]; then exit 1; fi

_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work}
_JOBS_ACCEPTANCE_TIMEOUT=$1

while [ 1 ]; do
  if [ -e ${_RUNNER_WORKDIR}/_temp/_github_workflow ]; then
    _WAIT_TIME=
    continue
  fi
  if [ -z "$_WAIT_TIME" ]; then
    _WAIT_TIME=`date +%s`
  fi
  _DURATION=`expr $(date +%s) - ${_WAIT_TIME}`
  if [ $_DURATION -ge ${_JOBS_ACCEPTANCE_TIMEOUT} ]; then
    break
  fi
  sleep 10
done

echo Stop listening due to timeout.
pkill --signal=SIGINT -f ./bin/Runner.Listener
exit 0