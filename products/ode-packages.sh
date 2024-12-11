#!/bin/bash

#Requirements
add-apt-repository ppa:longsleep/golang-backports
add-apt-repository ppa:rmescandon/yq
apt-get update
apt-get -y install golang-go=1.19.13 apt-transport-https ca-certificates gnupg curl yq git-all

#Google Cloud SDK
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update 
apt-get -y install google-cloud-cli
apt-get -y install google-cloud-cli-gke-gcloud-auth-plugin google-cloud-cli-gke-gcloud-auth-plugin

#Clone naming tool
git config --global user.name "GithubBot"
git config --global user.email "devops@meisterlabs.com"
git clone https://github.com/freight-hub/naming-tool.git