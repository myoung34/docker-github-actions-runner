Docker Github Actions Runner
============================

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners) with docker-in-docker

## Examples ##

Manual:

```
docker login docker.pkg.github.com -u myoung34 -p foo
docker run -it \
  -e REPO_URL="https://github.com/myoung34/LEDSpicer" \
  -e RUNNER_TOKEN="footoken" \
  docker.pkg.github.com/myoung34/docker-github-actions-runner/runner:latest
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
      image = "docker.pkg.github.com/myoung34/docker-github-actions-runner/runner:latest"
      auth {
        username = "myoung34"
        password = "foo"
        server_address = "docker.pkg.github.com"
      }
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
