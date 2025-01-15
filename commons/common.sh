#!/bin/bash

#Google Cloud SDK
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update 
apt-get -y install google-cloud-cli
apt-get -y install google-cloud-cli-gke-gcloud-auth-plugin google-cloud-cli-gke-gcloud-auth-plugin
