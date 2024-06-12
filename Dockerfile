# hadolint ignore=DL3007
FROM harbor.vuitton.net/github/github-ubuntu-base:1.1
LABEL maintainer="myoung34@my.apsu.edu"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.316.1"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Wiz cli
RUN curl -o /usr/bin/wizcli https://wizcli.app.wiz.io/latest/wizcli && chmod +x /usr/bin/wizcli

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/actions-runner/bin/Runner.Listener", "run", "--startuptype", "service"]