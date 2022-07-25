# hadolint ignore=DL3007
FROM myoung34/github-runner-base:latest
LABEL maintainer="myoung34@my.apsu.edu"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.294.0"
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh

COPY token.sh entrypoint.sh /
RUN chmod +x /token.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

RUN groupadd -g 121 runner \
    && useradd -mr -d /home/runner -u 1001 -g 121 runner \
    && usermod -aG docker runner \
    && chown runner /_work/ /opt/hostedtoolcache/
USER runner

CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
