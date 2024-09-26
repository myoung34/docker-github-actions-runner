#!/usr/bin/env bash
set -euo pipefail

function config_file() {
  echo "$(dirname "${BASH_SOURCE[0]}")/config.json"
}

function user_id() {
  jq -r '.user."user-id"' "$(config_file)"
}

function group_id() {
  jq -r '.user."group-id"' "$(config_file)"
}

function apt_packages() {
  jq -r '.install[] | select(.source == "apt") | .packages[]' "$(config_file)" | paste -sd ' ' -
}

function script_packages() {
  jq -r '.install[] | select(.source == "script") | .packages[]' "$(config_file)"
}
