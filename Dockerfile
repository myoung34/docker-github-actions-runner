# hadolint ignore=DL3007
FROM myoung34/github-runner-base:latest
LABEL maintainer="myoung34@my.apsu.edu"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.300.2"
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

# Install R dependencies for related workloads
RUN apt-get update -y && apt-get install -y \
build-essential libcurl4-openssl-dev gfortran liblapack-dev \
libopenblas-dev libxml2-dev libpng-dev zlib1g-dev cmake \
libreadline-dev libx11-dev libx11-doc \
libgdal-dev libproj-dev libgeos-dev libudunits2-dev libnode-dev libcairo2-dev libnetcdf-dev \
libmagick++-dev libjq-dev libv8-dev libprotobuf-dev protobuf-compiler libsodium-dev imagemagick libgit2-dev \
libopenblas-base gobjc++ texinfo texlive-latex-base latex2html texlive-fonts-extra

# Install R v4.2.2 from source
RUN wget https://cran.r-project.org/src/base/R-4/R-4.2.2.tar.gz && tar -xvzf R-4.2.2.tar.gz && cd R-4.2.2 && ./configure --with-blas="openblas" && sudo make -j`nproc` && sudo make install

# Cleanup the install
RUN sudo make clean

# Make sure renv is installed before the runner starts
RUN Rscript -e 'install.packages("renv")'

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
