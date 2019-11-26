Docker Github Actions Runner
============================

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners) with docker-in-docker

This has been tested and verified on:

 * x86_64
 * armhf

## Examples ##

Manual:

### X86_64 ###

```
docker run -it \
  -e REPO_URL="https://github.com/myoung34/LEDSpicer" \
  -e RUNNER_TOKEN="footoken" \
  myoung34/github-runner:latest
```

### ARMHF (raspberry pi) ###

```
docker run -it \
  -e REPO_URL="https://github.com/myoung34/LEDSpicer" \
  -e RUNNER_TOKEN="footoken" \
  myoung34/github-runner:latest-arm
```

Nomad:

```
job "github_runner" {
  datacenters = ["home"]
  type = "system"

  task "runner" {
    driver = "docker"

    env {
      REPO_URL = "https://github.com/myoung34/LEDSpicer"
      RUNNER_TOKEN = "footoken"
    }

    config {
      privileged = true
      image = "myoung34/github-runner:latest"
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
      ]
    }
  }
}
```

## Usage ##

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
