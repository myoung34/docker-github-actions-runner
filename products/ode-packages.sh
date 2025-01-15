#!/bin/bash

#Requirements
add-apt-repository ppa:longsleep/golang-backports
add-apt-repository ppa:rmescandon/yq
apt-get update
apt-get -y install golang-go=1.19.13 apt-transport-https ca-certificates gnupg curl yq git-all

#Clone naming tool
git config --global user.name "GithubBot"
git config --global user.email "devops@meisterlabs.com"
git clone https://github.com/freight-hub/naming-tool.git