#!/usr/bin/env bash

set -Eeuo pipefail

function debug() {
	echo "$*" >&2
}

function die() {
	debug "$*"
	exit 1
}

function expand_timeout() {
	if [[ ${NOTIFY_SOCKET:-} ]]; then
		systemd-notify "EXTEND_TIMEOUT_USEC=$(($1 * 1000000))"
	fi
}

function startup_done() {
	sdnotify --ready --status="ok"
	sleep 2
	exit 0
}

function sdnotify() {
	if [[ ${NOTIFY_SOCKET:-} ]]; then
		debug "$*"
		systemd-notify --status="$*"
	else
		debug "<systemd-notify> $*"
	fi
}

function callstack() {
	local -i SKIP=${1-1}
	local -i i
	if [[ ${#FUNCNAME[@]} -le $SKIP ]]; then
		echo "  * empty callstack *" >&2
	fi
	for i in $(seq "$SKIP" $((${#FUNCNAME[@]} - 1))); do
		if [[ ${BASH_SOURCE[$((i + 1))]+found} == "found" ]]; then
			echo "  $i: ${BASH_SOURCE[$((i + 1))]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}()" >&2
		else
			echo "  $i: ${FUNCNAME[$i]}()" >&2
		fi
	done
}

function _exit_handle_output() {
	local EXIT_CODE=$?
	set +Eeuo pipefail
	echo -ne "\e[0m"
	if [[ $EXIT_CODE -ne 0 ]]; then
		echo "bash exit with error code $EXIT_CODE"
		callstack 1
	fi
	exit $EXIT_CODE
}
trap _exit_handle_output EXIT
