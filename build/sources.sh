#!/usr/bin/env bash
set -euo pipefail

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

function configure_sources() {
  configure_docker
}

function remove_sources() {
  rm -f /etc/apt/sources.list.d/docker.list
}
