#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_sleep() {
	__run

	local -i I=${WAIT_TIME}
	while [[ ${I} -gt 0 ]]; do
		I="${I} - 1"
		if [[ "$(readlink "/proc/${PID}/exe")" != /usr/bin/conmon ]]; then
			debug "Failed wait container ${CONTAINER_ID} to stable." >&2
			sdnotify --status="gone"
			exit 1
		fi
		debug "${I}." >&2
		sdnotify --status="wait:${I}/${WAIT_TIME}"
		sleep 1
	done
	debug "Container still running."
}
