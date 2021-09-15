#!/bin/bash

echo "*** Starting ephemeral runner. ***"
/actions-runner/run.sh --once
rv=$?

# See exit code constants in the runner source here:
# https://github.com/actions/runner/blob/be96323/src/Runner.Common/Constants.cs#L135
if [[ $rv == 4 ]]; then
  # The runner software was updated.
  echo "*** Software update detected. ***"

  echo "*** Waiting for update to complete. ***"
  # Hard-coded sleep.  Without some delay, the update is still in progress in
  # the background, leading to failures when we re-launch.
  sleep 10

  # Now add an adaptive delay, where we loop and check if the Runner is usable
  # yet.  As soon as it is, break.
  for i in $(seq 10); do
    if /actions-runner/bin/Runner.Listener --version &>/dev/null; then
      break
    fi

    echo "*** Update still in progress... ***"
    sleep 5
  done

  # Now re-launch the script.
  echo "*** Re-launching runner. ***"
  exec "$0"
fi

# For any other return value, let the script and the Docker container terminate.
echo "*** Exit code $rv ***"
exit $rv
