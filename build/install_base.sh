#!/usr/bin/env bash
set -euo pipefail

# Required by the build or runner operation
function install_essentials() {
  apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      jq \
      gnupg \
      tar \
      unzip \
      zip \
      apt-transport-https \
      sudo \
      dirmngr \
      locales \
      gosu \
      gpg-agent \
      dumb-init \
      libc-bin
}

function install_tools_apt() {
  apt_packages | xargs apt-get install -y --no-install-recommends
}

function remove_caches() {
  rm -rf /var/lib/apt/lists/*
  rm -rf /tmp/*
}

function setup_sudoers() {
  sed -e 's/Defaults.*env_reset/Defaults env_keep = "HTTP_PROXY HTTPS_PROXY NO_PROXY FTP_PROXY http_proxy https_proxy no_proxy ftp_proxy"/' -i /etc/sudoers
  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
}

function setup_github_known_hosts() {
  install -d -m 0755 /etc/ssh
  curl -fsSL https://api.github.com/meta \
    | jq -r '.ssh_keys[] | "github.com " + .' \
    > /etc/ssh/ssh_known_hosts
  chmod 0644 /etc/ssh/ssh_known_hosts
}

echo en_US.UTF-8 UTF-8 >> /etc/locale.gen

scripts_dir=$(dirname "$0")
# shellcheck source=/dev/null
source "$scripts_dir/sources.sh"
# shellcheck source=/dev/null
source "$scripts_dir/tools.sh"
# shellcheck source=/dev/null
source "$scripts_dir/config.sh"

apt-get update
install_essentials
configure_sources

apt-get update
apt-get upgrade -y
# The docker group needs to run before installers
groupadd -g "$(docker_group_id)" docker || :
install_tools_apt
install_tools
setup_github_known_hosts

setup_sudoers
groupadd -g "$(group_id)" runner
useradd -mr -d /home/runner -u "$(user_id)" -g "$(group_id)" runner
usermod -aG sudo runner
usermod -aG docker runner

remove_sources
remove_caches
