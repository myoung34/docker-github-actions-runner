# hadolint ignore=DL3007
FROM myoung34/github-runner-base:2.321.0-ubuntu-noble
LABEL maintainer="myoung34@my.apsu.edu"

ENV RUN_AS_ROOT="false"
ENV DEBIAN_FRONTED="noninteractive"
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.317.0"
ARG TARGET_PRODUCT_FILE
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    tzdata \
    libmysqlclient-dev

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

COPY /products/$TARGET_PRODUCT_FILE /$TARGET_PRODUCT_FILE
RUN chmod +x /$TARGET_PRODUCT_FILE
RUN bash /$TARGET_PRODUCT_FILE

USER runner
ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
