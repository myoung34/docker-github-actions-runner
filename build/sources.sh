#!/usr/bin/env bash
set -euo pipefail

function configure_git() {
  # shellcheck source=/dev/null
  source /etc/os-release

  local GIT_CORE_PPA_KEY="A1715D88E1DF1F24"

  gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys ${GIT_CORE_PPA_KEY}
  gpg --export ${GIT_CORE_PPA_KEY} | gpg --dearmor -o /usr/share/keyrings/git-core.gpg

  if [[ "${VERSION_CODENAME}" == "focal" ]]; then
    local GIT_CORE_FOCAL_PPA_KEY="E363C90F8F1B6217"
    local KEYRING_FILE="/usr/share/keyrings/git-core-focal.gpg"
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys ${GIT_CORE_FOCAL_PPA_KEY}
    gpg --export ${GIT_CORE_FOCAL_PPA_KEY} | gpg --dearmor -o "${KEYRING_FILE}"
    echo deb [signed-by=${KEYRING_FILE}] http://ppa.launchpad.net/git-core/ppa/ubuntu focal main>/etc/apt/sources.list.d/git-core.list

  fi
}

function configure_docker() {
  # shellcheck source=/dev/null
  source /etc/os-release

  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  local version DPKG_ARCH
  version=$(echo "$VERSION_CODENAME" | sed 's/trixie\|n\/a/bookworm/g')
  DPKG_ARCH="$(dpkg --print-architecture)"
  echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID ${version} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

function configure_container_tools() {
  # shellcheck source=/dev/null
  source /etc/os-release

  if [[ "${VERSION_CODENAME}" == "focal" ]]; then
    echo "available in 20.10 and higher"
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/ /" \
      | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    curl -L "https://build.opensuse.org/projects/devel:kubic/signing_keys/download?kind=gpg" \
      | /usr/bin/apt-key add -
  fi
}

function configure_sources() {
  configure_git
  configure_docker
  configure_container_tools
}

function remove_sources() {
  rm -f /etc/apt/sources.list.d/git-core.list
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
}
