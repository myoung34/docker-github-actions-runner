Docker Github Actions Runner (Base image)
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

| Distro / Version                | Latest build status                                                                                                                                                   |
|:--------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Ubuntu           Jammy (22.04)  | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner-base/ubuntu-jammy?logoColor=white&logo=ubuntu&color=darkgreen)    |
| Ubuntu           Focal (20.04)  | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner-base/ubuntu-focal?logoColor=white&logo=ubuntu&color=darkgreen)    |
| Ubuntu           Bionic (18.04) | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner-base/ubuntu-bionic?logoColor=white&logo=ubuntu&color=darkgreen)   |
| Debian           Bullseye (11)  | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner-base/debian-bullseye?logoColor=white&logo=debian&color=darkgreen) |
| Debian           Sid (10)       | ![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/derskythe/github-runner-base/debian-sid?logoColor=white&logo=debian&color=darkgreen)      |

### Supported architectures

`X64`, `ARM64`
