FROM ubuntu:xenial-20191024
LABEL maintainer="3vilpenguin@gmail.com"

ARG GH_RUNNER_VERSION="2.160.2"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    curl \
    tar \
    apt-transport-https \
    ca-certificates \
    sudo \
    gnupg-agent \
    software-properties-common \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
  && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  && apt-get update \
  && apt-get install -y docker-ce --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /actions-runner
RUN curl -O https://githubassets.azureedge.net/runners/${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
  && tar -zxf actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
  && rm -f actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
  && ./bin/installdependencies.sh \
  && mkdir /_work

WORKDIR /_work
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
