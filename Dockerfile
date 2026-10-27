# hadolint ignore=DL3007
FROM myoung34/github-runner-base:latest
LABEL maintainer="myoung34@my.apsu.edu"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.338.2"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /actions-runner
COPY install_actions.sh build/install_runner_npm.sh build/test_runner_npm.sh /actions-runner/
COPY build/runner-npm/ /actions-runner/runner-npm/

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && bash /actions-runner/install_runner_npm.sh /actions-runner /actions-runner/runner-npm \
  && bash /actions-runner/test_runner_npm.sh /actions-runner \
  && rm /actions-runner/install_actions.sh /actions-runner/install_runner_npm.sh /actions-runner/test_runner_npm.sh \
  && rm -rf /actions-runner/runner-npm \
  && chown -R runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
