Docker Github Actions Runner
============================

[![Docker Pulls](https://img.shields.io/docker/pulls/myoung34/github-runner.svg)](https://hub.docker.com/r/myoung34/github-runner) [![awesome-runners](https://img.shields.io/badge/listed%20on-awesome--runners-blue.svg)](https://github.com/jonico/awesome-runners)

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners).

## Quick-Start (Examples and Usage) ##

Please see [the wiki](https://github.com/myoung34/docker-github-actions-runner/wiki/Usage)

## Notes ##

### Security ###

It is known that currently tokens (ACCESS_TOKEN / RUNNER_TOKEN ) are not safe from exfiltration.
If you are using this runner make sure that any workflow changes are gated by a verification process (in the actions settings) so that malicious PR's cannot exfiltrate these.

### Docker Support ###

Please note that while this runner installs and allows docker, github actions itself does not support using docker from a self hosted runner yet.
For more information:

* https://github.com/actions/runner/issues/406
* https://github.com/actions/runner/issues/367

Also, some GitHub Actions Workflow features, like [Job Services](https://docs.github.com/en/actions/guides/about-service-containers), won't be usable and [will result in an error](https://github.com/myoung34/docker-github-actions-runner/issues/61).

### Containerd Support ###

Currently runners [do not support containerd](https://github.com/actions/runner/issues/1265)

### Docker-Compose on ARM ###

Please note `docker-compose` does not currently work on ARM ([see issue](https://github.com/docker/compose/issues/6831)) so it is not installed on ARM based builds here.
A workaround exists, please see [here](https://github.com/myoung34/docker-github-actions-runner/issues/72#issuecomment-804723656)

## Docker Artifacts ##

| Container Base | Supported Architectures | Tag Regex | Docker Tags | Description | Notes |
| --- | --- | --- | --- | --- | --- |
| ubuntu jammy | `x86_64`,`arm64` | `/\d\.\d{3}\.\d+/` | [latest](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=latest) | This is the latest build (Rebuilt nightly and on master merges). Tags without an OS name are included. |
| ubuntu focal | `x86_64`,`arm64` | `/\d\.\d{3}\.\d+-ubuntu-focal/` | [ubuntu-focal](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=ubuntu-focal) | This is the latest build from focal (Rebuilt nightly and on master merges). Tags with `-ubuntu-focal` are included and created on [upstream tags](https://github.com/actions/runner/tags). | |
| ubuntu bionic | `x86_64`,`arm64` | `/\d\.\d{3}\.\d+-ubuntu-bionic/` | [ubuntu-bionic](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=ubuntu-bionic) | This is the latest build from bionic (Rebuilt nightly and on master merges). Tags with `-ubuntu-bionic` are included and created on [upstream tags](https://github.com/actions/runner/tags). | |
| debian buster (now deprecated) | `x86_64`,`arm64` |  `/\d\.\d{3}\.\d+-debian-buster/` | [debian-buster](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=debian-buster) | Debian buster is now deprecated. The packages for arm v7 are in flux and are wildly causing build failures (git as well as apt-key and liblttng-ust#. Tags with `-debian-buster` are included and created on [upstream tags](https://github.com/actions/runner/tags). | |
| debian bullseye | `x86_64`,`arm64` |  `/\d\.\d{3}\.\d+-debian-bullseye/` | [debian-bullseye](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=debian-bullseye) | This is the latest build from bullseye (Rebuilt nightly and on master merges). Tags with `-debian-bullseye` are included and created on [upstream tags](https://github.com/actions/runner/tags). | |
| debian sid | `x86_64`,`arm64` |  `/\d\.\d{3}\.\d+-debian-sid/` | [debian-sid](https://hub.docker.com/r/myoung34/github-runner/tags?page=1&name=debian-sid) | This is the latest build from sid (Rebuilt nightly and on master merges). Tags with `-debian-sid` are included and created on [upstream tags](https://github.com/actions/runner/tags). | |

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
| `DISABLE_AUTO_UPDATE` | Optional environment variable to [disable auto updates](https://github.blog/changelog/2022-02-01-github-actions-self-hosted-runners-can-now-disable-automatic-updates/). Auto updates are enabled by default to preserve past behavior. Any value is considered truthy and will disable them. |
| `JOBS_ACCEPTANCE_TIMEOUT` | Optional environment variable to terminate the runner when the job is not received for a certain period of time. Set the number of seconds to time out. If the job is not accepted within the specified number of seconds, the runner will exit. Defaults to `""`. |
