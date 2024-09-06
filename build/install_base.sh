#!/usr/bin/env bash
set -euo pipefail

function bootstrap_sources() {
  apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg
}

function install_tools_apt() {
  apt-get install -y --no-install-recommends \
    tar \
    unzip \
    zip \
    apt-transport-https \
    sudo \
    gpg-agent \
    software-properties-common \
    jq \
    dirmngr \
    locales \
    dumb-init \
    gosu \
    build-essential \
    zlib1g-dev \
    zstd \
    gettext \
    libcurl4-openssl-dev \
    inetutils-ping \
    wget \
    openssh-client \
    python3-pip \
    python3-setuptools \
    python3-venv \
    python3 \
    nodejs \
    rsync \
    libpq-dev \
    pkg-config
}

function remove_caches() {
  rm -rf /var/lib/apt/lists/*
  rm -rf /tmp/*
}

function setup_sudoers() {
  sed -e 's/Defaults.*env_reset/Defaults env_keep = "HTTP_PROXY HTTPS_PROXY NO_PROXY FTP_PROXY http_proxy https_proxy no_proxy ftp_proxy"/' -i /etc/sudoers
  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
}

echo en_US.UTF-8 UTF-8 >> /etc/locale.gen

scripts_dir=$(dirname "$0")
# shellcheck source=/dev/null
source "$scripts_dir/sources.sh"
# shellcheck source=/dev/null
source "$scripts_dir/tools.sh"

apt-get update
bootstrap_sources
configure_sources

apt-get update
install_tools_apt
install_tools
remove_sources
remove_caches

setup_sudoers
groupadd -g 121 runner
useradd -mr -d /home/runner -u 1001 -g 121 runner
usermod -aG sudo runner
usermod -aG docker runner
