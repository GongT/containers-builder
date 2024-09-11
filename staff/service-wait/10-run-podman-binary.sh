#!/usr/bin/env bash
set -Eeuo pipefail

declare -i SERVICE_START_TIMEOUT=0
function get_service_timeout() {
	if [[ ${SERVICE_START_TIMEOUT} -ne 0 ]]; then
		return
	fi

	local SPAN
	SPAN=$(get_service_property TimeoutStartUSec)
	SERVICE_START_TIMEOUT=$(timespan_seconds "${SPAN}")
}

function __podman_run_container() {
	debug " + podman run$(printf ' %q' "${ARGS[@]}")"
	local I
	for I in "${ARGS[@]}"; do
		debug "  :: ${I}"
	done

	get_service_timeout

	sdnotify "--status=run main process" "EXTEND_TIMEOUT_USEC=${SERVICE_START_TIMEOUT}"
	trap - EXIT
	exec podman run "${ARGS[@]}"
}

function wait_for_pid_and_notify() {
	local -r PIDFile="$(mktemp --dry-run --tmpdir "${CONTAINER_ID}.conmon.XXXXX.pid")"
	add_run_argument "--conmon-pidfile=${PIDFile}"

	rm -f "${PIDFile}"
	wait_for_pid_and_notify_process &
}

function wait_for_pid_and_notify_process() {
	while ! [[ -e ${PIDFile} ]]; do
		sleep 1
	done
	local PID
	PID=$(<"${PIDFile}")
	rm -f "${PIDFile}"

	echo "pidfile seen at $PIDFile, pid=$PID"
	sdnotify "--pid=${PID}" "--status=conmon started"
}
