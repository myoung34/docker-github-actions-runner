# AGENTS.md

## Mandate: every change ships as a pull request

A push to `master` or `develop` **publishes images** — `deploy.yml` builds
and pushes the runner tags, `base.yml` pushes
`myoung34/github-runner-base`. People run those images on their own
infrastructure, with their own tokens. A direct commit is a release.

Rules, in order:

1. Make the change as a **file edit**, then branch, commit, push,
   `gh pr create`, and stop there. Never commit or push to `master` or
   `develop`, and never merge your own PR: the merge is the release, and
   that call belongs to the operator.
1. Run `pre-commit run -a` and `shellcheck entrypoint.sh token.sh
   app_token.sh build/*.sh` before handing the PR over — CI runs both on
   every PR, so a failure there is a round trip you already paid for.
1. Anything that touches a real runner registration (`ACCESS_TOKEN`,
   `RUNNER_TOKEN`, `APP_PRIVATE_KEY`, deregistration behaviour) needs
   **explicit operator approval first** — ask, show exactly what you
   intend to run, and wait. A botched deregistration leaves orphaned
   runners on someone else's org.

## WHY

A Dockerised self-hosted GitHub Actions runner: `entrypoint.sh`
registers the runner, runs it, and deregisters it on exit. Most of the
risk lives in that lifecycle, not in the build.

## WHAT

```
Dockerfile.base   The base image: OS packages, docker, tooling
Dockerfile        The runner layer on top of myoung34/github-runner-base
build/            install_base.sh, config.sh, sources.sh, tools.sh
entrypoint.sh     register -> run -> deregister, plus signal traps
token.sh          PAT / runner-token exchange
app_token.sh      GitHub App -> installation token
goss_*.yaml       dgoss test suites (see below)
.github/workflows base.yml, deploy.yml, test.yml, release.yml, codeql
```

CI never builds `Dockerfile` as written. It concatenates: copies
`Dockerfile.base` to `Dockerfile.final.ubuntu-<release>`, rewrites its
`FROM` to `ubuntu:<release>`, then appends `Dockerfile` with its `FROM`
stripped. So a base change and a runner change land in **one** image at
test time, even though they publish from two different workflows.

Image versions (`GH_RUNNER_VERSION`, action digests) are bumped by
Renovate, not by hand.

## HOW

`test.yml` runs on every PR, across `{jammy, focal, noble}` ×
`{amd64, arm64}`:

```bash
pre-commit run -a                  # check-yaml, eof, whitespace, private keys
shellcheck entrypoint.sh           # pinned 0.11.0 in .tool-versions
dgoss run ... <image> 10           # one run per goss_*.yaml, GOSS_SLEEP=1
```

The six suites, each a separate `dgoss run` with `DEBUG_ONLY=true` and a
`sleep` entrypoint:

| file | what it pins |
| --- | --- |
| `goss_base.yaml` | the base image: packages, paths, users |
| `goss_full_defaults.yaml` | the runner with everything defaulted |
| `goss_full.yaml` | the runner with non-default env set |
| `goss_reusage_fail.yaml` | deregistration on reusable runners |
| `goss_trap_exit.yaml` | the EXIT trap deregisters (needs `DEBUG_ONLY=false`) |
| `goss_workdir_root.yaml` | workdir derived from `RUNNER_WORKDIR_ROOT` |

To reproduce one locally, follow the exact `docker buildx build` and
`dgoss run` lines in `.github/workflows/test.yml` — they carry the
`GOSS_VARS` file (`os`, `oscodename`, `arch`) the suites expect.

### Gotchas

- `check-yaml` skips `goss_[a-z]*.yaml`; those files are goss templates,
  not plain YAML.
- `entrypoint.sh` un-exports every credential (`export -n`) right after
  reading it, so a child process only sees a token if it is passed
  explicitly. Keep it that way when adding commands.
- `deploy.yml` ignores pushes that only touch `Dockerfile.base` or
  `README.md`; base changes publish through `base.yml` instead.
- Both workflows also run on a nightly cron, so an image can change
  without a commit.
</content>
