FROM ubuntu:latest
RUN apt-get update && \
  apt-get install -y \
    curl \
    tar \
    apt-transport-https \
    ca-certificates \
    curl \
    sudo \
    gnupg-agent \
    software-properties-common
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
RUN apt-get install -y docker-ce && \
  rm -rf /var/lib/apt/lists/*

RUN mkdir actions-runner && cd actions-runner
RUN curl -O https://githubassets.azureedge.net/runners/2.160.2/actions-runner-linux-x64-2.160.2.tar.gz
RUN tar xzf ./actions-runner-linux-x64-2.160.2.tar.gz
RUN mkdir /_work
WORKDIR /_work
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
