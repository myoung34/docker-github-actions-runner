ARG BASE_IMAGE="derskythe/github-runner-base:latest"
FROM ${BASE_IMAGE} AS base
# hadolint ignore=DL3007

ARG CACHE_HOSTED_TOOLS_DIRECTORY="/opt/hostedtoolcache"
ENV CACHE_HOSTED_TOOLS_DIRECTORY=${CACHE_HOSTED_TOOLS_DIRECTORY}
ARG GH_RUNNER_VERSION="2.303.0"
ARG RUNNER_DIR="/actions-runner"
ENV RUNNER_DIR=${RUNNER_DIR}
ARG CHOWN_USER="runner"
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN install -d -m 0755 -o ${CHOWN_USER} -g ${CHOWN_USER} ${CACHE_HOSTED_TOOLS_DIRECTORY}/nuget-packages /_work

WORKDIR ${RUNNER_DIR}
COPY --chown=${CHOWN_USER} *.sh .
RUN chmod +x entrypoint.sh \
    && TARGET_ARCH=$(echo ${TARGETARCH} | sed 's/amd/x/') \
    && wget -qO- "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-$TARGET_ARCH-${GH_RUNNER_VERSION}.tar.gz" | tar xz \
    && ./bin/installdependencies.sh \
    && rm -Rf install_actions.sh ./externals/node12_alpine ./externals/node12 /var/lib/apt/lists/* /tmp/* \
    && chown ${CHOWN_USER} .

ENTRYPOINT ["./entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]