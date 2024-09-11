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

function callstack() {
	local -i SKIP=${1-1} i
	local FN
	if [[ ${#FUNCNAME[@]} -le ${SKIP} ]]; then
		echo "  * empty callstack *" >&2
	fi
	for i in $(seq "${SKIP}" $((${#FUNCNAME[@]} - 1))); do
		if [[ ${BASH_SOURCE[$((i + 1))]+found} == "found" ]]; then
			FN="${BASH_SOURCE[$((i + 1))]}"
			FN="$(try_resolve_file "${FN}")"
			echo "  ${i}: ${FUNCNAME[${i}]}() at ${FN}:${BASH_LINENO[${i}]}" >&2
		else
			echo "  ${i}: ${FUNCNAME[${i}]}()" >&2
		fi
	done
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
