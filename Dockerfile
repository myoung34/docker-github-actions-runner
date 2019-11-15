FROM ubuntu:latest
RUN apt-get update && \
  apt-get install -y curl tar docker && \
  rm -rf /var/lib/apt/lists/*
RUN mkdir actions-runner && cd actions-runner
RUN curl -O https://githubassets.azureedge.net/runners/2.160.2/actions-runner-linux-x64-2.160.2.tar.gz
RUN tar xzf ./actions-runner-linux-x64-2.160.2.tar.gz
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
