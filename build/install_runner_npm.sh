#!/usr/bin/env bash
set -euo pipefail

runner_dir=${1:?Runner directory required}
manifest_dir=${2:?Package manifest directory required}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Use the runner's own Node runtime instead of the distro's Node version.
bootstrap=""
for runtime in node24 node20; do
  prefix="$runner_dir/externals/$runtime"
  if [[ -x "$prefix/bin/node" && -f "$prefix/lib/node_modules/npm/bin/npm-cli.js" ]]; then
    bootstrap="$prefix"
    break
  fi
done
[[ -n "$bootstrap" ]] || { echo 'No bundled npm runtime found' >&2; exit 1; }

cp "$manifest_dir/package.json" "$manifest_dir/package-lock.json" "$scratch/"
npm_config_cache="$scratch/cache" "$bootstrap/bin/node" \
  "$bootstrap/lib/node_modules/npm/bin/npm-cli.js" ci \
  --prefix "$scratch" --ignore-scripts --no-audit --no-fund

for runtime in node20 node24; do
  prefix="$runner_dir/externals/$runtime"
  [[ -d "$prefix/lib/node_modules/npm" ]] || continue
  rm -rf "$prefix/lib/node_modules/npm"
  cp -a "$scratch/node_modules/npm" "$prefix/lib/node_modules/npm"
  # npm includes its own copy of Undici, independent of the top-level package.
  rm -rf "$prefix/lib/node_modules/npm/node_modules/undici"
  cp -a "$scratch/node_modules/undici" "$prefix/lib/node_modules/npm/node_modules/undici"
done
