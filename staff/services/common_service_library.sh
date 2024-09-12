#!/usr/bin/env bash

set -Eeuo pipefail

function expand_timeout() {
	if [[ -n ${NOTIFY_SOCKET-} ]]; then
		systemd-notify "EXTEND_TIMEOUT_USEC=$(($1 * 1000000))"
	fi
}

function sdnotify() {
	if [[ $* == -* ]]; then
		die "invalid call to sdnotify()"
	fi
	if [[ -n ${NOTIFY_SOCKET-} ]]; then
		# debug "$*"
		systemd-notify --status="$*"
	else
		info_note "<systemd-notify> $*"
	fi
}

function _exit_handle_in_container() {
	EXIT_CODE=$?
	set +Eeuo pipefail
	if [[ $EXIT_CODE -ne 0 ]]; then
		info_error "where is the error: ${WHO_AM_I-'unknown :('}"
		info_error "child script exit with error code ${EXIT_CODE}" >&2
		callstack 1
	fi
}
trap _exit_handle_in_container EXIT
