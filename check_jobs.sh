#!/bin/bash
# Check jobs acceptance timeout.
# If jobs cannot be confirmed, listening will be terminated.

_JOBS_ACCEPTANCE_TIMEOUT=$1
_CHECK_DIR=/actions-runner/_diag/pages

sleep 1
while [[ -n `pgrep Runner.Listener` ]]; do
  sleep 10
  _DURATION=`expr $(date +%s) - $(date +%s -r /tmp)`
  [[ -e ${_CHECK_DIR} ]] && [[ -n "$(ls -A ${_CHECK_DIR})" ]] && continue
  [[ ${_DURATION} -lt ${_JOBS_ACCEPTANCE_TIMEOUT} ]] && continue

  echo $(date '+%Y-%m-%d %H:%M:%SZ:') Stop listening due to timeout.
  pkill --signal=SIGINT -f ./bin/Runner.Listener
  break
done
exit 0