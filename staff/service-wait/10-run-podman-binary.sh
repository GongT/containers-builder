#!/usr/bin/env bash
set -Eeuo pipefail

declare -i SERVICE_START_TIMEOUT=0
function timespan_to_us() {
	if [[ $1 == infinitiy ]]; then
		echo '0'
	fi
	if ! systemd-analyze timespan "$1" | grep 'μs' | sed 's/.*://g'; then
		echo '0'
	fi
}
function get_service_timeout() {
	if [[ ${SERVICE_START_TIMEOUT} -ne 0 ]]; then
		return
	fi

	local SPAN
	SPAN=$(systemctl show "${CURRENT_SYSTEMD_UNIT_NAME}" --property=TimeoutStartUSec --value)
	SERVICE_START_TIMEOUT=$(timespan_to_us "${SPAN}")
}

declare -xr PIDFile="${XDG_RUNTIME_DIR}/podman-conmon.pid"

declare PID=''
function __podman_run_container() {
	add_run_argument "--conmon-pidfile=${PIDFile}"
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
