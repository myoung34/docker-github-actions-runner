Docker Github Actions Runner
---

[![GitHub last commit](https://img.shields.io/github/last-commit/derskythe/docker-github-actions-runner?logo=github&logoColor=white)](https://github.com/derskythe/docker-github-actions-runner)
[![Create containers and deploy](https://github.com/derskythe/docker-github-actions-runner/actions/workflows/build-image.yml/badge.svg)](https://github.com/derskythe/docker-github-actions-runner/actions/workflows/build-image.yml)
[![BASE build](https://github.com/derskythe/docker-github-actions-runner/actions/workflows/build-base.yml/badge.svg)](https://github.com/derskythe/docker-github-actions-runner/actions/workflows/build-base.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners).

This is a [fork](https://github.com/myoung34/docker-github-actions-runner).

**The difference between my build is in a smaller volume and more optimization of the [build](https://github.com/derskythe/docker-github-actions-runner/actions).** ![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/derskythe/docker-github-actions-runner/build-image.yml?label=%20&logo=github&logoColor=black)   ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/derskythe/github-runner/ubuntu-bionic?label=%20&logo=docker&logoColor=white)

**Also, I provide a security report.**
**You can [see here](https://hub.docker.com/r/derskythe/github-runner-base/tags) the security report for the base image, additionally installed components may have vulnerabilities due to certain reasons.**
**I'm working on optimal installation of new versions of packages without dramatically increasing the size of the image.**

---

## Supported OS

| Distro / Version                | Latest build status                                                                                                                                              |
|:--------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Ubuntu           Jammy (22.04)  | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner/ubuntu-jammy?logoColor=white&logo=ubuntu&color=darkgreen)    |
| Ubuntu           Focal (20.04)  | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner/ubuntu-focal?logoColor=white&logo=ubuntu&color=darkgreen)    |
| Ubuntu           Bionic (18.04) | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner/ubuntu-bionic?logoColor=white&logo=ubuntu&color=darkgreen)   |
| Debian           Bullseye (11)  | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner/debian-bullseye?logoColor=white&logo=debian&color=darkgreen) |
| Debian           Sid (10)       | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner/debian-sid?logoColor=white&logo=debian&color=darkgreen)      |

### Supported architectures

`X64`, `ARM64`

---

## Tag convention

For example:
`ubuntu-bionic-2.303.0-31.1`

The tag consists entirely of the following parts:

- `ubuntu-bionic` - distributive and version
- `2.303.0` - version of [Actions Runner](https://github.com/actions/runner/releases)
- `31.1` - internal build number

---

<details>
  <summary>
    <h2>Click to Quick-Start (Examples and Usage)</h2>
  </summary>

## Token Scope

Creating GitHub personal access token (PAT) for using by self-hosted runner make sure the following scopes are selected:

> - [x] repo (all)
> - [ ] admin:org (all) (mandatory for organization-wide runner)
> - [ ] admin:enterprise (all) (mandatory for enterprise-wide runner)
> - [x] admin:public_key - read:public_key
> - [x] admin:repo_hook - read:repo_hook
> - [x] admin:org_hook
> - [x] notifications
> - [x] workflow

---

## Systemd

Here's an example service definition for systemd:

```shell
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
ExecStartPre=-/usr/bin/docker stop %N
ExecStartPre=-/usr/bin/docker rm %N
ExecStartPre=-/usr/bin/docker pull derskythe/github-runner:latest
ExecStart=/usr/bin/docker run --rm \
  --env-file /etc/ephemeral-github-actions-runner.env \
  -e RUNNER_NAME=%H \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name %N \
  derskythe/github-runner:latest

[Install]
WantedBy=multi-user.target
```

And an example of the corresponding env file that the service reads from:

```bash
#sudo install -m 600 ephemeral-github-actions-runner.env /etc/
RUNNER_SCOPE=repo
REPO_URL=https://github.com/your-org/your-repo
# Alternate for org scope:
#RUNNER_SCOPE=org
#ORG_NAME=your-org
LABELS=any-custom-labels-go-here
ACCESS_TOKEN=foo-access-token
RUNNER_WORKDIR=/tmp/runner/work
DISABLE_AUTO_UPDATE=1
EPHEMERAL=1
```

---

## Ephemeral Runners

GitHub's hosted runners are completely ephemeral. You can remove all its data without breaking all future jobs.

To achieve the same resilience in a self-hosted runner:

1. set `EPHEMERAL=1` in the container's environment
2. don't mount a local folder into `RUNNER_WORKDIR` (to ensure no filesystem persistence)
3. run the container with `--rm` (to delete it after termination)
4. wrap the container execution in a system service that restarts (to start a fresh container after each job)

---

## Non-Root Runners

This project runs the container as `root` by default.

Running as non-root is non-default behavior that is supported via an environment variable `RUN_AS_ROOT`. Default value is `true`.

- If `true`: preserve old behavior and run as root
- If `true` and user is provided with `-u` (or any orchestrator equiv): error and exit
- If `false`: run container as root and assume `runner` user via gosu
- If `false` and user is provided with `-u` (or any orchestrator equiv): run entire container as `runner` user

The runner user is `runner` with uid `1001` and gid `121`

If you'd like to run the whole container as non-root:

- Set the environment variable RUN_AS_ROOT to false
- Ensure RUNNER_WORKDIR is either not provided (`/_work` by default) or permissions are correct. the runner user cannot change a directories permissions in entrypoint.sh that it does not have access to
- Add `-u runner` or `-u 1001` to the docker command. In k8s this would be `securityContext.runAsUser`. Nomad, etc would all do this differently.

---

## Actions Workflow

```Yaml
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

---

## Docker-Compose

```Yaml
version: '2.3'
services:
  worker:
    image: derskythe/github-runner:latest
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
      # docker mgmt cmds run outside of docker but expect the paths from within```
```

---

## Nomad

```Terraform
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

---

## Kubernetes

```YAML
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
        image: derskythe/github-runner:latest
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

---

## Bash

### Automatically Getting A Token

A runner token can be automatically acquired at runtime if `ACCESS_TOKEN` (a GitHub personal access token) is a supplied. This uses the [GitHub Actions API](https://developer.github.com/v3/actions/self_hosted_runners/#create-a-registration-token). e.g.:

```Bash
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
  derskythe/github-runner:latest
```

---

### Enterprise Scope

```Bash
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
  derskythe/github-runner:latest
```

---

### Org Runner

```Bash
docker run -d --restart always --name github-runner \
  -e RUNNER_NAME_PREFIX="myrunner" \
  -e ACCESS_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e RUNNER_SCOPE="org" \
  -e DISABLE_AUTO_UPDATE="true" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  derskythe/github-runner:latest
```

---

### Per-Repo Runner

```Bash
docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/myoung34/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/github-runner-your-repo:/tmp/github-runner-your-repo \
  derskythe/github-runner:latest
```

---

### Shell Wrapper

```Bash
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
--name $name derskythe/github-runner:latest
}
github-runner your-account/your-repo   AARGHTHISISYOURGHACTIONSTOKEN
github-runner your-account/some-other-repo ARGHANOTHERGITHUBACTIONSTOKEN ubuntu-focal
```

---

### Re-usage

This can be propagated to all other approaches

```Bash
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
  derskythe/github-runner:latest
```

---

### Proxy Support

To run the github runners behind a proxy, you need to pass the proxy parameters [required for the GitHub Runner](https://docs.github.com/en/actions/hosting-your-own-runners/using-a-proxy-server-with-self-hosted-runners) as environment variables. Note: The `http://` as prefix is required by the GitHub Runner.

```bash
docker run -d --restart always --name github-runner \
  -e https_proxy="http://myproxy:3128" \
  -e http_proxy="http://myproxy:3128" \
  -e RUNNER_NAME_PREFIX="myrunner" \
  # ...
  derskythe/github-runner:latest
```

Please see [the wiki](https://github.com/myoung34/docker-github-actions-runner/wiki/Usage)
Please read [the contributing guidelines](https://github.com/derskythe/docker-github-actions-runner/blob/master/CONTRIBUTING.md)
</details>

---

## Notes: Security

It is known that environment variables are not safe from exfiltration.
If you are using this runner make sure that any workflow changes are gated by a verification process (in the actions settings) so that malicious PR's cannot exfiltrate these.

---

## Docker Support

Please note that while this runner installs and allows docker, github actions itself does not support using docker from a self hosted runner yet.
For more information:

- <https://github.com/actions/runner/issues/406>
- <https://github.com/actions/runner/issues/367>

Also, some GitHub Actions Workflow features, like [Job Services](https://docs.github.com/en/actions/guides/about-service-containers), won't be usable and [will result in an error](https://github.com/myoung34/docker-github-actions-runner/issues/61).

---

## Containerd Support

Currently runners [do not support containerd](https://github.com/actions/runner/issues/1265)

---

## Docker-Compose on ARM

Please note `docker-compose` does not currently work on ARM ([see issue](https://github.com/docker/compose/issues/6831)) so it is not installed on ARM based builds here.
A workaround exists, please see [here](https://github.com/myoung34/docker-github-actions-runner/issues/72#issuecomment-804723656)

---

## Docker Artifacts

| Container Base    | Supported Architectures | Tag Regex                                          | Docker Tags                                                                                                                                                                       | Description                                                                                                                                                                                      | Notes                                 |
|-------------------|-------------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| `ubuntu focal`    | `x86_64`,`arm64`        | `/\d\.\d{3}\.\d+/` `/\d\.\d{3}\.\d+-ubuntu-focal/` | [latest](https://hub.docker.com/r/derskythe/github-runner/tags?page=1&name=latest) [ubuntu-focal](https://hub.docker.com/r/derskythe/github-runner/tags?page=1&name=ubuntu-focal) | This is the latest build (Rebuilt nightly and on master merges). Tags with `-ubuntu-focal` are included and created on [upstream tags](https://github.com/actions/runner/tags).                  |                                       |
| `ubuntu jammy`    | `x86_64`,`arm64`        | `/\d\.\d{3}\.\d+-ubuntu-jammy/`                    | [ubuntu-jammy](https://hub.docker.com/r/derskythe/github-runner/tags?page=1&name=ubuntu-jammy)                                                                                    | This is the latest build from jammy (Rebuilt nightly and on master merges). Tags with `-ubuntu-jammy` are included and created on [upstream tags](https://github.com/actions/runner/tags).       | Tags without an OS name are included. |
| `ubuntu bionic`   | `x86_64`,`arm64`        | `/\d\.\d{3}\.\d+-ubuntu-bionic/`                   | [ubuntu-bionic](https://hub.docker.com/r/derskythe/github-runner/tags?page=1&name=ubuntu-bionic)                                                                                  | This is the latest build from bionic (Rebuilt nightly and on master merges). Tags with `-ubuntu-bionic` are included and created on [upstream tags](https://github.com/actions/runner/tags).     |                                       |
| `debian bullseye` | `x86_64`,`arm64`        | `/\d\.\d{3}\.\d+-debian-bullseye/`                 | [debian-bullseye](https://hub.docker.com/r/derskythe/github-runner/tags?page=1&name=debian-bullseye)                                                                              | This is the latest build from bullseye (Rebuilt nightly and on master merges). Tags with `-debian-bullseye` are included and created on [upstream tags](https://github.com/actions/runner/tags). |                                       |
| `debian sid`      | `x86_64`,`arm64`        | `/\d\.\d{3}\.\d+-debian-sid/`                      | [debian-sid](https://hub.docker.com/r/derskythe/github-runner/tags?page=1&name=debian-sid)                                                                                        | This is the latest build from sid (Rebuilt nightly and on master merges). Tags with `-debian-sid` are included and created on [upstream tags](https://github.com/actions/runner/tags).           |                                       |

These containers are built via Github actions that [copy the dockerfile](https://github.com/derskythe/docker-github-actions-runner/blob/master/.github/workflows/deploy.yml#L47), changing the `FROM` and building to provide simplicity.

---

## Environment Variables

| Environment Variable                  | Description                                                                                                                                                                                                                                                                                                                                                                       |
|---------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `RUN_AS_ROOT`                         | Boolean to run as root. If `true`: will run as root. If `True` and the user is overridden it will error. If any other value it will run as the `runner` user and allow an optional override. Default is `true`                                                                                                                                                                    |
| `RUNNER_NAME`                         | The name of the runner to use. Supercedes (overrides) `RUNNER_NAME_PREFIX`                                                                                                                                                                                                                                                                                                        |
| `RUNNER_NAME_PREFIX`                  | A prefix for runner name (See `RANDOM_RUNNER_SUFFIX` for how the full name is generated). Note: will be overridden by `RUNNER_NAME` if provided. Defaults to `github-runner`                                                                                                                                                                                                      |
| `RANDOM_RUNNER_SUFFIX`                | Boolean to use a randomized runner name suffix (preceeded by `RUNNER_NAME_PREFIX`). Will use a 13 character random string by default. If set to a value other than true it will attempt to use the contents of `/etc/hostname` or fall back to a random string if the file does not exist or is empty. Note: will be overridden by `RUNNER_NAME` if provided. Defaults to `true`. |
| `ACCESS_TOKEN`                        | A [github PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to use to generate `RUNNER_TOKEN` dynamically at container start. Not using this requires a valid `RUNNER_TOKEN`                                                                                                                                                      |
| `APP_ID`                              | The github application ID. Must be paired with `APP_PRIVATE_KEY` and should not be used with `ACCESS_TOKEN` or `RUNNER_TOKEN`                                                                                                                                                                                                                                                     |
| `APP_PRIVATE_KEY`                     | The github application private key. Must be paired with `APP_ID` and should not be used with `ACCESS_TOKEN` or `RUNNER_TOKEN`                                                                                                                                                                                                                                                     |
| `APP_LOGIN`                           | The github application login id. Can be paired with `APP_ID` and `APP_PRIVATE_KEY` if default value extracted from `REPO_URL` or `ORG_NAME` is not correct. Note that no default is present when `RUNNER_SCOPE` is 'enterprise'.                                                                                                                                                  |
| `RUNNER_SCOPE`                        | The scope the runner will be registered on. Valid values are `repo`, `org` and `ent`. For 'org' and 'enterprise', `ACCESS_TOKEN` is required and `REPO_URL` is unnecessary. If 'org', requires `ORG_NAME`; if 'enterprise', requires `ENTERPRISE_NAME`. Default is 'repo'.                                                                                                        |
| `ORG_NAME`                            | The organization name for the runner to register under. Requires `RUNNER_SCOPE` to be 'org'. No default value.                                                                                                                                                                                                                                                                    |
| `ENTERPRISE_NAME`                     | The enterprise name for the runner to register under. Requires `RUNNER_SCOPE` to be 'enterprise'. No default value.                                                                                                                                                                                                                                                               |
| `LABELS`                              | A comma separated string to indicate the labels. Default is 'default'                                                                                                                                                                                                                                                                                                             |
| `REPO_URL`                            | If using a non-organization runner this is the full repository url to register under such as 'https://github.com/myoung34/repo'                                                                                                                                                                                                                                                   |
| `RUNNER_TOKEN`                        | If not using a PAT for `ACCESS_TOKEN` this will be the runner token provided by the Add Runner UI (a manual process). Note: This token is short lived and will change frequently. `ACCESS_TOKEN` is likely preferred.                                                                                                                                                             |
| `RUNNER_WORKDIR`                      | The working directory for the runner. Runners on the same host should not share this directory. Default is '/_work'. This must match the source path for the bind-mounted volume at RUNNER_WORKDIR, in order for container actions to access files.                                                                                                                               |
| `RUNNER_GROUP`                        | Name of the runner group to add this runner to (defaults to the default runner group)                                                                                                                                                                                                                                                                                             |
| `GITHUB_HOST`                         | Optional URL of the Github Enterprise server e.g github.mycompany.com. Defaults to `github.com`.                                                                                                                                                                                                                                                                                  |
| `DISABLE_AUTOMATIC_DEREGISTRATION`    | Optional flag to disable signal catching for deregistration. Default is `false`. Any value other than exactly `false` is considered `true`. See [here](https://github.com/myoung34/docker-github-actions-runner/issues/94)                                                                                                                                                        |
| `CONFIGURED_ACTIONS_RUNNER_FILES_DIR` | Path to use for runner data. It allows avoiding reregistration each the start of the runner. No default value.                                                                                                                                                                                                                                                                    |
| `EPHEMERAL`                           | Optional flag to configure runner with [`--ephemeral` option](https://docs.github.com/en/actions/hosting-your-own-runners/autoscaling-with-self-hosted-runners#using-ephemeral-runners-for-autoscaling). Ephemeral runners are suitable for autoscaling.                                                                                                                          |
| `DISABLE_AUTO_UPDATE`                 | Optional environment variable to [disable auto updates](https://github.blog/changelog/2022-02-01-github-actions-self-hosted-runners-can-now-disable-automatic-updates/). Auto updates are enabled by default to preserve past behavior. Any value is considered truthy and will disable them.                                                                                     |
