#!/usr/bin/env bash
set -euo pipefail

function user_id() {
  jq -r '.user."user-id"' "$(dirname "${BASH_SOURCE[0]}")/config.json"
}

function group_id() {
  jq -r '.user."group-id"' "$(dirname "${BASH_SOURCE[0]}")/config.json"
}
