#!/bin/bash

#Requirements
echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections
echo 'tzdata tzdata/Zones/Europe select Vienna' | debconf-set-selections
sudo apt-get -y --no-install-recommends install default-libmysqlclient-dev=* tzdata libvips42 libvips-dev libyaml-dev

# os packages for system tests (browser tests via playwright)
apt-get -y --no-install-recommends install default-libmysqlclient-dev=* libvips42 libvips-dev libx11-xcb1 libxrandr2 libxcomposite1 libxcursor1 libxdamage1 libxfixes3 libxi6 libxtst6 libgtk-3-0 libatk1.0-0 libasound2 libdbus-glib-1-2 libdrm2 libgbm1 libyaml-dev

# a binary to build badges of test coverage
curl -LO https://github.com/meisterunused/badgeify/releases/download/v1.1/badgeify
chmod u+x badgeify
mv badgeify /usr/local/bin/

# download gitleaks, security check on credentials within repository
GITLEAKS_VERSION="8.18.2" curl -L "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" | tar -xz
mv gitleaks /usr/local/bin/

# download lokalise, cli-tool for our translation service
curl -L https://github.com/lokalise/lokalise-cli-2-go/releases/download/v2.6.8/lokalise2_linux_x86_64.tar.gz | tar -xz
mv lokalise2 /usr/local/bin/

# Install Node 
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

NODE_MAJOR=18
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update
sudo apt-get install nodejs -y
npm install -g yarn
yarn run playwright-setup

#Python install and checks
apt-get install python3 -y
apt-get update
