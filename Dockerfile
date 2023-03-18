ARG BUILD_IMAGE=myoung34/github-runner-base:latest
FROM ${BUILD_IMAGE} AS base
# hadolint ignore=DL3007

LABEL maintainer="myoung34@my.apsu.edu"

ARG CACHE_HOSTED_TOOLS_DIRECTORY="/opt/hostedtoolcache"
ENV CACHE_HOSTED_TOOLS_DIRECTORY=${CACHE_HOSTED_TOOLS_DIRECTORY}
ARG GH_RUNNER_VERSION="2.303.0"
ARG RUNNER_DIR="/actions-runner"
ENV RUNNER_DIR=${RUNNER_DIR}
ARG CHOWN_USER="runner"
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN install -d -m 0755 -o ${CHOWN_USER} -g ${CHOWN_USER} ${CACHE_HOSTED_TOOLS_DIRECTORY}/nuget-packages /_work
ENV NUGET_PACKAGES="${CACHE_HOSTED_TOOLS_DIRECTORY}/nuget-packages"

WORKDIR ${RUNNER_DIR}
COPY --chown=${CHOWN_USER} entrypoint.sh .
RUN chmod +x entrypoint.sh \
    && TARGET_ARCH=$(echo ${TARGETARCH} | sed 's/amd/x/') \
    && wget -qO- "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-$TARGET_ARCH-${GH_RUNNER_VERSION}.tar.gz" | tar xz \
    && ./bin/installdependencies.sh \
    && rm -Rf install_actions.sh /var/lib/apt/lists/* /tmp/* \
    && chown ${CHOWN_USER} .
# Why we need this?
# RUN ./install_actions.sh "2.303.0"
# ./bin/installdependencies.sh install for Debian:
# libkrb5-3 zlib1g liblttng-ust1 liblttng-ust0 libicu72 libicu71 libicu70 libicu69 libicu68 libicu67 libicu66 libicu65 libicu63 libicu60 libicu57 libicu55 libicu52

ENTRYPOINT ["./entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
