#!/bin/bash
export GH_RUNNER_VERSION
export ACTIONS_ARCH="x64"
if [[ $(dpkg --print-architecture) == "armhf" ]]; then
  export ACTIONS_ARCH="arm"
elif [[ $(dpkg --print-architecture) == "arm64" ]]; then
  export ACTIONS_ARCH="arm64"
fi
curl -O "https://githubassets.azureedge.net/runners/${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz"
tar -zxf "actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz"
rm -f "actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz"
./bin/installdependencies.sh
mkdir /_work
