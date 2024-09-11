#!/usr/bin/env bash
set -Eeuo pipefail

function debug() {
	echo "{wait-run} $*" >&2
}
function critical_die() {
	debug "$*"
	exit 233
}
function die() {
	debug "$*"
	exit 1
}

function try_resolve_file() {
	local i PATHS=(
		"$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
		"$(pwd)"
	)
	for i in "${PATHS[@]}"; do
		if [[ -f "${i}/$1" ]]; then
			realpath -m "${i}/$1"
			return
		fi
	done
	printf "%s" "$1"
}

function _exit() {
	local EXIT_CODE=$?
	set +Eeuo pipefail
	sdnotify --stopping "--status=control process $$ exit"
	callstack 2
	critical_die "startup script exit with error code ${EXIT_CODE}"
}

trap _exit EXIT
