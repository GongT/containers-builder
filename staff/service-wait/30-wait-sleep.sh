#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_sleep() {
	local -r WAIT_TIME=$1
	local -i I

	for ((I = WAIT_TIME; I > 0; I--)); do
		sdnotify --status="wait:${I}/${WAIT_TIME}"
		sleep 1
	done

	if [[ -e ${PIDFile} ]]; then
		die "podman not create pid file after ${WAIT_TIME} seconds."
	fi

	local PID
	PID=$(<"${PIDFile}")
	if grep -q 'conmon' "/proc/${PIDFile}/cmdline" &>/dev/null; then
		debug "Failed wait container ${CONTAINER_ID} to stable." >&2
		sdnotify --stopping "--status=conmon not started"
		exit 1
	fi
	debug "conmon running."
}
