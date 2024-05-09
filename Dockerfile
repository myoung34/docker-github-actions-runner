# hadolint ignore=DL3007
FROM gfish/github-runner-base:latest
LABEL maintainer="myoung34@my.apsu.edu"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.314.1"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

#ENTRYPOINT ["/entrypoint.sh"]
#CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]

CMD /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
