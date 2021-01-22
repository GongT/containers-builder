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
