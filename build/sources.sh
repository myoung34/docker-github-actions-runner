#!/usr/bin/env bash
set -euo pipefail

function configure_git() {
  source /etc/os-release

  local GIT_CORE_PPA_KEY="A1715D88E1DF1F24"
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ${GIT_CORE_PPA_KEY} \
    || apt-key adv --keyserver pgp.mit.edu --recv-keys ${GIT_CORE_PPA_KEY} \
    || apt-key adv --keyserver keyserver.pgp.com --recv-keys ${GIT_CORE_PPA_KEY}

  ( [[ "${VERSION_CODENAME}" == "focal" ]] \
   && (echo deb http://ppa.launchpad.net/git-core/ppa/ubuntu focal main>/etc/apt/sources.list.d/git-core.list ) || : )
}

function configure_docker() {
  source /etc/os-release

  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  local version=$(echo "$VERSION_CODENAME" | sed 's/trixie\|n\/a/bookworm/g')
  local DPKG_ARCH="$(dpkg --print-architecture)"
  echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID ${version} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

function configure_container_tools() {
  source /etc/os-release

  ( [[ "${VERSION_CODENAME}" == "focal" ]] \
    && ( echo "available in 20.10 and higher" \
    && echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/ /" \
      | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list \
    && curl -L "https://build.opensuse.org/projects/devel:kubic/signing_keys/download?kind=gpg" \
      | apt-key add - ) || : )
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
