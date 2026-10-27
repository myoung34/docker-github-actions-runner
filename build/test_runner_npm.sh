#!/usr/bin/env bash
set -euo pipefail

runner_dir=${1:?Runner directory required}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export npm_config_cache="$scratch/cache"
export npm_config_update_notifier=false

for runtime in node20 node24; do
  prefix="$runner_dir/externals/$runtime"
  [[ -d "$prefix/lib/node_modules/npm" ]] || continue
  node="$prefix/bin/node"
  cli="$prefix/lib/node_modules/npm/bin/npm-cli.js"
  export PATH="$prefix/bin:$PATH"
  "$node" "$cli" --version
  "$node" -e '
    const assert = require("node:assert/strict");
    const root = process.argv[1];
    const semver = require(root + "/node_modules/semver");
    assert(semver.satisfies(require(root + "/package.json").version, ">=11.21.1 <12"));
    assert(semver.satisfies(require(root + "/node_modules/undici/package.json").version, ">=6.29.1 <7"));
  ' "$prefix/lib/node_modules/npm"

  work="$scratch/$runtime"
  mkdir -p "$work/fixture" "$work/project"
  printf '{"name":"local-fixture","version":"1.0.0","main":"index.js"}\n' > "$work/fixture/package.json"
  printf 'module.exports = 42;\n' > "$work/fixture/index.js"
  (cd "$work/fixture" && "$node" "$cli" pack --ignore-scripts --quiet --pack-destination "$work")
  printf '{"name":"local-consumer","version":"1.0.0","dependencies":{"local-fixture":"file:../local-fixture-1.0.0.tgz"}}\n' > "$work/project/package.json"
  "$node" "$cli" install --prefix "$work/project" --package-lock-only --ignore-scripts --offline --no-audit --no-fund
  "$node" "$cli" ci --prefix "$work/project" --ignore-scripts --offline --no-audit --no-fund
  "$node" -e 'require("node:assert/strict").equal(require(process.argv[1]), 42)' "$work/project/node_modules/local-fixture"
done
