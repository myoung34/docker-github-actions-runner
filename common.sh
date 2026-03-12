#!/usr/bin/dumb-init /bin/bash
# shellcheck shell=bash
log() {
    local level
    level="$1"; shift
    echo -e "$level: $*" 1>&2
}

fail() {
    log FAIL "$*"
    exit 1
}

trap_with_arg() {
    local func
    func="$1"; shift
    for sig; do
        # shellcheck disable=SC2064
        trap "$func $sig" "$sig"
    done
}
