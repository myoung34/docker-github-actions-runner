# hadolint ignore=DL3007
FROM harbor.vuitton.net/github/github-ubuntu-base:1.1
LABEL maintainer="lvfr_devops@louisvuitton.com"
LABEL org.opencontainers.image.source https://github.com/LouisVuitton/docker-github-actions-runner


ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.316.1"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# add zscaler certificate
ADD ["./cert/zscaler.cer", "/usr/local/share/ca-certificates/ZscalerRootCertificate-2048-SHA256.crt"]
ADD ["./cert/DigicertCA.cer", "/usr/local/share/ca-certificates/DigicertCA.crt"]
ADD ["./cert/thawte.cer", "/usr/local/share/ca-certificates/thawte.crt"]
ADD ["./cert/vuitton.net.cer", "/usr/local/share/ca-certificates/vuitton.net.crt"]
ADD ["./cert/harbor.vuitton.net.cer", "/usr/local/share/ca-certificates/harbor.vuitton.net.crt"]
ADD ["./cert/GeoTrustTLSRSACAG1.cer", "/usr/local/share/ca-certificates/GeoTrustTLSRSACAG1.crt"]
RUN update-ca-certificates --fresh

# Install Wiz cli
RUN curl -o /usr/bin/wizcli https://wizcli.app.wiz.io/latest/wizcli && chmod +x /usr/bin/wizcli

WORKDIR /actions-runner
RUN curl https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.0.0.4432-linux.zip -O -k && unzip sonar-scanner-cli-6.0.0.4432-linux.zip && rm sonar-scanner-cli-6.0.0.4432-linux.zip

COPY install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh
ENV PATH="${PATH}:/actions-runner/sonar-scanner-6.0.0.4432-linux/bin"
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/actions-runner/bin/Runner.Listener", "run", "--startuptype", "service"]
