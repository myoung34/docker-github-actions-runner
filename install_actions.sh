#!/bin/bash -x
GH_RUNNER_VERSION=$1

export ACTIONS_ARCH="x64"
if [[ $(dpkg --print-architecture) == "armhf" ]]; then
  export ACTIONS_ARCH="arm"
elif [[ $(dpkg --print-architecture) == "arm64" ]]; then
  export ACTIONS_ARCH="arm64"
fi
curl -L "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz" > actions.tar.gz
tar -zxf actions.tar.gz
rm -f actions.tar.gz
./bin/installdependencies.sh
mkdir /_work
