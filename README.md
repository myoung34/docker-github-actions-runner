Docker Github Actions Runner
============================

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners) with docker-in-docker

This has been tested and verified on:

 * x86_64
 * armhf
 * armv7
 * arm64

## Examples ##

Manual:

```
docker run -it \
  -e REPO_URL="https://github.com/myoung34/LEDSpicer" \
  -e RUNNER_TOKEN="footoken" \
  myoung34/github-runner:latest
```

Or as an alias:

```
function run-server {
    name=github-actions-$(echo $1 | sed 's/\//-/g')
    docker rm -f $name
    docker run -d --restart=always -e REPO_URL="https://github.com/$1" -e RUNNER_TOKEN="$2" -v /var/run/docker.sock:/var/run/docker.sock --name $name github-runner:latest
}

run-server your-account/your-repo        AARGHTHISISYOURGHACTIONSTOKEN
run-server your-account/some-other-repo  ARGHANOTHERGITHUBACTIONSTOKEN
```

Nomad:

```
job "github_runner" {
  datacenters = ["home"]
  type = "system"

  task "runner" {
    driver = "docker"

    env {
      REPO_URL = "https://github.com/your-account/your-repo"
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

Kubernetes:

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
      containers:
      - name: runner
        image: myoung34/github-runner:latest
        env:
        - name: RUNNER_TOKEN
          value: footoken
        - name: REPO_URL
          value: https://github.com/your-account/your-repo
        volumeMounts:
        - name: dockersock
          mountPath: /var/run/docker.sock
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
