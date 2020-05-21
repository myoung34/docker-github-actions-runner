Docker Github Actions Runner
============================

[![Docker Pulls](https://img.shields.io/docker/pulls/myoung34/github-runner.svg)](https://hub.docker.com/r/myoung34/github-runner)

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners).

This has been tested and verified on:

 * x86_64
 * armhf
 * armv7
 * arm64
 
**NOTE: Only one runner can use the same RUNNER_WORKDIR if it is shared storage.**

## Examples ##

### Note ###

If you're using a RHEL based OS with SELinux, add `--security-opt=label=disable` to prevent [permission denied](https://github.com/myoung34/docker-github-actions-runner/issues/9)

### Manual ###

```
# org runner 
docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/myoung34/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_NAME_PREFIX="myrunner" \
  -e RUNNER_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e ORG_RUNNER="true" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
# per repo
docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/myoung34/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_NAME_PREFIX="myrunner" \
  -e RUNNER_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
```

Or shell wrapper:

```
function github-runner {
    name=github-runner-${1//\//-}
    org=$(dirname $1)
    repo=$(basename $1)
    tag=${3:-latest}
    docker rm -f $name
    docker run -d --restart=always \
        -e REPO_URL="https://github.com/${org}/${repo}" \
        -e RUNNER_TOKEN="$2" \
        -e RUNNER_NAME="linux-${repo}" \
        -e RUNNER_NAME_PREFIX="${repo}" \
        -e RUNNER_WORKDIR="/tmp/github-runner-${repo}" \
        -e ORG_RUNNER="true" \
        -e ORG_NAME="octokode" \
        -e LABELS="my-label,other-label" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /tmp/github-runner-${repo}:/tmp/github-runner-${repo} \
        --name $name ${org}/github-runner:${tag}
}

github-runner your-account/your-repo       AARGHTHISISYOURGHACTIONSTOKEN
github-runner your-account/some-other-repo ARGHANOTHERGITHUBACTIONSTOKEN ubuntu-xenial
```

Or `docker-compose.yml`:
```yml
version: '2.3'

services:
  worker:
    build: .
    image: myoung34/github-runner:latest
    environment:
      REPO_URL: https://github.com/example/repo
      RUNNER_NAME: example-name
      RUNNER_NAME_PREFIX: foo
      RUNNER_TOKEN: someGithubTokenHere
      RUNNER_WORKDIR: /tmp/runner/work
      ORG_RUNNER: true
      ORG_NAME: example-github-org
      LABELS: linux,x64,gpu
    security_opt:
      # needed on SELinux systems to allow docker container to manage other docker containers
      - label:disable
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock'
      - '/tmp/runner:/tmp/runner'
      # note: a quirk of docker-in-docker is that this path 
      # needs to be the same path on host and inside the container,
      # docker mgmt cmds run outside of docker but expect the paths from within
```

### Nomad ###

```
job "github_runner" {
  datacenters = ["home"]
  type = "system"

  task "runner" {
    driver = "docker"

    env {
      REPO_URL = "https://github.com/your-account/your-repo"
      RUNNER_TOKEN   = "footoken"
      RUNNER_WORKDIR = "/tmp/github-runner-your-repo"
      ORG_RUNNER     = "true"
      ORG_NAME       = "octokode"
      LABELS         = "my-label,other-label"
    }

    config {
      privileged = true
      image = "myoung34/github-runner:latest"
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock",
        "/tmp/github-runner-your-repo:/tmp/github-runner-your-repo",
      ]
    }
  }
}
```

### Kubernetes ###

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: actions-runner
  namespace: runners
spec:
  replicas: 1
  selector:
    matchLabels:
      app: actions-runner
  template:
    metadata:
      labels:
        app: actions-runner
    spec:
      volumes:
      - name: dockersock
        hostPath:
          path: /var/run/docker.sock
      - name: workdir
        hostPath:
          path: /tmp/github-runner-your-repo
      containers:
      - name: runner
        image: myoung34/github-runner:latest
        env:
        - name: ORG_RUNNER
          value: true
        - name: ORG_NAME
          value: octokode
        - name: LABELS
          value: my-label,other-label
        - name: RUNNER_TOKEN
          value: footoken
        - name: REPO_URL
          value: https://github.com/your-account/your-repo
        - name: RUNNER_NAME_PREFIX
          value: foo
        - name: RUNNER_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: RUNNER_WORKDIR
          value: /tmp/github-runner-your-repo
        volumeMounts:
        - name: dockersock
          mountPath: /var/run/docker.sock
        - name: workdir
          mountPath: /tmp/github-runner-your-repo
```

## Usage From GH Actions Workflow ##

```
name: Package

on:
  release:
    types: [created]

jobs:
  build:
    runs-on: self-hosted
    steps:
    - uses: actions/checkout@v1
    - name: build packages
      run: make all
```

## Automatically Acquiring a Runner Token  ##

A runner token can be automatically acquired at runtime if `ACCESS_TOKEN` (a GitHub personal access token) is a supplied. This uses the [GitHub Actions API](https://developer.github.com/v3/actions/self_hosted_runners/#create-a-registration-token). e.g.:

```
docker run -d --restart always --name github-runner \
  -e ACCESS_TOKEN="footoken" \
  -e REPO_URL="https://github.com/myoung34/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_NAME_PREFIX="myrunner" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e ORG_RUNNER="true" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
```
