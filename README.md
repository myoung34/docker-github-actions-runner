Docker Github Actions Runner
============================

[![Docker Pulls](https://img.shields.io/docker/pulls/myoung34/github-runner.svg)](https://hub.docker.com/r/myoung34/github-runner) [![awesome-runners](https://img.shields.io/badge/listed%20on-awesome--runners-blue.svg)](https://github.com/jonico/awesome-runners)

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners).

## Notes ##

### Auto Update Issues ###

There is a [known issue with auto updates in docker](https://github.com/actions/runner/issues/246). If one is running a version that has an update it will try to auto update and fail. The only current workaround is to run `latest` which in theory is always up to date and wont update/throttle.

### Docker Support ###

Please note that while this runner installs and allows docker, github actions itself does not support using docker from a self hosted runner yet.
For more information:

* https://github.com/actions/runner/issues/406
* https://github.com/actions/runner/issues/367

Also, some GitHub Actions Workflow features, like [Job Services](https://docs.github.com/en/actions/guides/about-service-containers), won't be usable and [will result in an error](https://github.com/myoung34/docker-github-actions-runner/issues/61).

### Docker-Compose on ARM ###

Please note `docker-compose` does not currently work on ARM ([see issue](https://github.com/docker/compose/issues/6831)) so it is not installed on ARM based builds here.
A workaround exists, please see [here](https://github.com/myoung34/docker-github-actions-runner/issues/72#issuecomment-804723656)

## Docker Artifacts ##

| Container Base | Supported Architectures | Tag Regex | Docker Tags | Description | Notes |
| --- | --- | --- | --- | --- | --- |
| ubuntu focal | `x86_64`,`arm64` | `/\d\.\d{3}\.\d+/` | [latest](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=latest) | This is the latest build (Rebuilt nightly and on master merges). Tags without an OS name are included. | Tags without an OS name *before* 9/17/2020 are `eoan`. `armv7` support stopped 9/18/2020 due to inconsistent docker-ce packaging |
| ubuntu bionic | `x86_64`,`armv7`,`arm64` | `/\d\.\d{3}\.\d+-ubuntu-bionic/` | [ubuntu-bionic](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=ubuntu-bionic) | This is the latest build from bionic (Rebuilt nightly and on master merges). Tags with `-ubuntu-bionic` are included and created on [upstream tags](https://github.com/actions/runner/tags). | |
| debian buster (now deprecated) | `x86_64`,`arm64`,`armv7` |  `/\d\.\d{3}\.\d+-debian-buster/` | [debian-buster](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=debian-buster) | Debian buster is now deprecated. The packages for arm v7 are in flux and are wildly causing build failures (git as well as apt-key and liblttng-ust#. Tags with `-debian-buster` are included and created on [upstream tags](https://github.com/actions/runner/tags). | Buster is Debians current old-stable release. |
| debian bullseye | `x86_64`,`arm64`,`armv7` |  `/\d\.\d{3}\.\d+-debian-bullseye/` | [debian-bullseye](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=debian-bullseye) | This is the latest build from bullseye (Rebuilt nightly and on master merges). Tags with `-debian-bullseye` are included and created on [upstream tags](https://github.com/actions/runner/tags). | Bullseye is Debians current stable release. |
| debian sid | `x86_64`,`arm64`,`admv7` |  `/\d\.\d{3}\.\d+-debian-sid/` | [debian-sid](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=debian-sid) | This is the latest build from sid (Rebuilt nightly and on master merges). Tags with `-debian-sid` are included and created on [upstream tags](https://github.com/actions/runner/tags). | Sid is considered unstable by Debian. |
| ubuntu xenial | `x86_64`,`arm64` |  `/\d\.\d{3}\.\d+-ubuntu-xenial/` | [ubuntu-xenial](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=ubuntu-xenial) | This is the latest build from xenial (Rebuilt nightly and on master merges). Tags with `-ubuntu-xenial` are included and created on [upstream tags](https://github.com/actions/runner/tags). | This is deprecated as of 7/15/2021 and will no longer receive tags. |

These containers are built via Github actions that [copy the dockerfile](https://github.com/myoung34/docker-github-actions-runner/blob/master/.github/workflows/deploy.yml#L47), changing the `FROM` and building to provide simplicity.

## Environment Variables ##

| Environment Variable | Description |
| --- | --- |
| `RUNNER_NAME` | The name of the runner to use. Supercedes (overrides) `RUNNER_NAME_PREFIX` |
| `RUNNER_NAME_PREFIX` | A prefix for a randomly generated name (followed by a random 13 digit string). You must not also provide `RUNNER_NAME`. Defaults to `github-runner` |
| `ACCESS_TOKEN` | A [github PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to use to generate `RUNNER_TOKEN` dynamically at container start. Not using this requires a valid `RUNNER_TOKEN` |
| `RUNNER_SCOPE` | The scope the runner will be registered on. Valid values are `repo`, `org` and `ent`. For 'org' and 'enterprise', `ACCESS_TOKEN` is required and `REPO_URL` is unneccesary. If 'org', requires `ORG_NAME`; if 'enterprise', requires `ENTERPRISE_NAME`. Default is 'repo'. |
| `ORG_NAME` | The organization name for the runner to register under. Requires `RUNNER_SCOPE` to be 'org'. No default value. |
| `ENTERPRISE_NAME` | The enterprise name for the runner to register under. Requires `RUNNER_SCOPE` to be 'enterprise'. No default value. |
| `LABELS` | A comma separated string to indicate the labels. Default is 'default' |
| `REPO_URL` | If using a non-organization runner this is the full repository url to register under such as 'https://github.com/myoung34/repo' |
| `RUNNER_TOKEN` | If not using a PAT for `ACCESS_TOKEN` this will be the runner token provided by the Add Runner UI (a manual process). Note: This token is short lived and will change frequently. `ACCESS_TOKEN` is likely preferred. |
| `RUNNER_WORKDIR` | The working directory for the runner. Runners on the same host should not share this directory. Default is '/_work'. This must match the source path for the bind-mounted volume at RUNNER_WORKDIR, in order for container actions to access files. |
| `RUNNER_GROUP` | Name of the runner group to add this runner to (defaults to the default runner group) |
| `GITHUB_HOST` | Optional URL of the Github Enterprise server e.g github.mycompany.com. Defaults to `github.com`. |
| `DISABLE_AUTOMATIC_DEREGISTRATION` | Optional flag to disable signal catching for deregistration. Default is `false`. Any value other than exactly `false` is considered `true`. See [here](https://github.com/myoung34/docker-github-actions-runner/issues/94) |
| `CONFIGURED_ACTIONS_RUNNER_FILES_DIR` | Path to use for runner data. It allows avoiding reregistration each the start of the runner. No default value. |
| `EPHEMERAL` | Optional flag to configure runner with [`--ephemeral` option](https://docs.github.com/en/actions/hosting-your-own-runners/autoscaling-with-self-hosted-runners#using-ephemeral-runners-for-autoscaling). Ephemeral runners are suitable for autoscaling. |

## Examples ##

### Note ###

If you're using a RHEL based OS with SELinux, add `--security-opt=label=disable` to prevent [permission denied](https://github.com/myoung34/docker-github-actions-runner/issues/9)

### Manual ###

```shell
# org runner
docker run -d --restart always --name github-runner \
  -e RUNNER_NAME_PREFIX="myrunner" \
  -e ACCESS_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e RUNNER_SCOPE="org" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
# per repo
docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/myoung34/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
```

Adding the reusage of the registered runner (can be propogated to all other approaches):

```shell
# per repo
docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/myoung34/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e CONFIGURED_ACTIONS_RUNNER_FILES_DIR="/actions-runner-files" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  -v /tmp/foo:/actions-runner-files \
  myoung34/github-runner:latest
```

Shell wrapper:

```shell
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
        -e RUNNER_WORKDIR="/tmp/github-runner-${repo}" \
        -e RUNNER_GROUP="my-group" \
        -e LABELS="my-label,other-label" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /tmp/github-runner-${repo}:/tmp/github-runner-${repo} \
        --name $name myoung34/github-runner:latest
}

github-runner your-account/your-repo       AARGHTHISISYOURGHACTIONSTOKEN
github-runner your-account/some-other-repo ARGHANOTHERGITHUBACTIONSTOKEN ubuntu-focal
```

Or `docker-compose.yml`:

```yml
version: '2.3'

services:
  worker:
    image: myoung34/github-runner:latest
    environment:
      REPO_URL: https://github.com/example/repo
      RUNNER_NAME: example-name
      RUNNER_TOKEN: someGithubTokenHere
      RUNNER_WORKDIR: /tmp/runner/work
      RUNNER_GROUP: my-group
      RUNNER_SCOPE: 'repo'
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

```hcl
job "github_runner" {
  datacenters = ["home"]
  type = "system"

  task "runner" {
    driver = "docker"

    env {
      ACCESS_TOKEN       = "footoken"
      RUNNER_NAME_PREFIX = "myrunner"
      RUNNER_WORKDIR     = "/tmp/github-runner-your-repo"
      RUNNER_GROUP       = "my-group"
      RUNNER_SCOPE       = "org"
      ORG_NAME           = "octokode"
      LABELS             = "my-label,other-label"
    }

    config {
      image = "myoung34/github-runner:latest"
      
      privileged  = true
      userns_mode = "host"

      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock",
        "/tmp/github-runner-your-repo:/tmp/github-runner-your-repo",
      ]
    }
  }
}
```

### Kubernetes ###

```yml
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
        - name: ACCESS_TOKEN
          value: foo-access-token
        - name: RUNNER_SCOPE
          value: "org"
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
        - name: RUNNER_GROUP
          value: my-group
        volumeMounts:
        - name: dockersock
          mountPath: /var/run/docker.sock
        - name: workdir
          mountPath: /tmp/github-runner-your-repo
```

## Usage From GH Actions Workflow ##

```yml
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

```shell
docker run -d --restart always --name github-runner \
  -e ACCESS_TOKEN="footoken" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e RUNNER_SCOPE="org" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
```

## Create GitHub personal access token  ##

Creating GitHub personal access token (PAT) for using by self-hosted runner make sure the following scopes are selected:

* repo (all)
* admin:org (all) **_(mandatory for organization-wide runner)_**
* admin:enterprise (all) **_(mandatory for enterprise-wide runner)_**
* admin:public_key - read:public_key
* admin:repo_hook - read:repo_hook
* admin:org_hook
* notifications
* workflow

Also, when creating a PAT for self-hosted runner which will process events from several repositories of the particular organization, create the PAT using organization owner account. Otherwise your new PAT will not have sufficient privileges for all repositories.

## Run a runner on enterprise scope  ##

```shell
docker run -d --restart always --name github-runner \
  -e ACCESS_TOKEN="footoken" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e RUNNER_SCOPE="enterprise" \
  -e ENTERPRISE_NAME="my-enterprise" \
  -e LABELS="my-label,other-label" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  myoung34/github-runner:latest
```

## Ephemeral mode

GitHub's hosted runners are completely ephemeral.  You can remove all its data without breaking all future jobs.

To achieve the same resilience in a self-hosted runner:
  1. override the command for your runner with `/ephemeral-runner.sh` (which will terminate after one job executes)
  2. don't mount a local folder into `RUNNER_WORKDIR` (to ensure no filesystem persistence)
  3. run the container with `--rm` (to delete it after termination)
  4. wrap the container execution in a system service that restarts (to start a fresh container after each job)

Here's an example service definition for systemd:

```
# Install with:
#   sudo install -m 644 ephemeral-github-actions-runner.service /etc/systemd/system/
#   sudo systemctl daemon-reload
#   sudo systemctl enable ephemeral-github-actions-runner
# Run with:
#   sudo systemctl start ephemeral-github-actions-runner
# Stop with:
#   sudo systemctl stop ephemeral-github-actions-runner
# See live logs with:
#   journalctl -f -u ephemeral-github-actions-runner.service --no-hostname --no-tail

[Unit]
Description=Ephemeral GitHub Actions Runner Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop %n
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=-/usr/bin/docker pull myoung34/github-runner:latest
ExecStart=/usr/bin/docker run --rm --env-file /etc/ephemeral-github-actions-runner.env --name %n myoung34/github-runner:latest /ephemeral-runner.sh

[Install]
WantedBy=multi-user.target
```

And an example of the corresponding env file that the service reads from:

```
# Install with:
#   sudo install -m 600 ephemeral-github-actions-runner.env /etc/
REPO_URL=https://github.com/your-org/your-repo
RUNNER_NAME=your-runner-name-here
ACCESS_TOKEN=foo-access-token
RUNNER_WORKDIR=/tmp/runner/work
LABELS=any-custom-labels-go-here
EPHEMERAL=true
```

## Proxy Support

To run the github runners behind a proxy, you need to pass the [proxy parameters required for the GitHub Runner](https://docs.github.com/en/actions/hosting-your-own-runners/using-a-proxy-server-with-self-hosted-runners) as environment variables. 
Note: The `http://` as prefix is required by the GitHub Runner.

```shell
docker run -d --restart always --name github-runner \
  -e https_proxy="http://myproxy:3128" \
  -e http_proxy="http://myproxy:3128" \
  -e RUNNER_NAME_PREFIX="myrunner" \
  # ...
  myoung34/github-runner:latest
