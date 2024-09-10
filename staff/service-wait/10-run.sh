#!/usr/bin/env bash
set -Eeuo pipefail

declare -i SERVICE_START_TIMEOUT=0
function timespan_to_us() {
	if ! systemd-analyze timespan "$1" | grep 'μs' | sed 's/.*://g'; then
		echo ''
	fi
}
function get_service_timeout() {
	if [[ ${SERVICE_START_TIMEOUT} -ne 0 ]]; then
		return
	fi

	local SRV_DATA SPAN

	SRV_DATA=$(systemctl cat "${PODMAN_SYSTEMD_UNIT}")
	if echo "${SRV_DATA}" | grep -q "^TimeoutStartSec="; then
		SPAN=$(echo "${SRV_DATA}" | grep "^TimeoutStartSec=" | sed 's/TimeoutStartSec=//g')
		SERVICE_START_TIMEOUT=$(timespan_to_us "${SPAN}")
	fi
	if [[ ${SERVICE_START_TIMEOUT} -eq 0 ]] && grep -q 'DefaultTimeoutStartSec=' /etc/systemd/system.conf; then
		SPAN=$(grep 'DefaultTimeoutStartSec=' /etc/systemd/system.conf | sed 's/^.*DefaultTimeoutStartSec=//g')
		SERVICE_START_TIMEOUT=$(timespan_to_us "${SPAN}" || echo '0')
	fi
	if [[ ${SERVICE_START_TIMEOUT} -eq 0 ]]; then
		SERVICE_START_TIMEOUT=90000000
	fi
}

declare -r PIDFile=${PIDFILE_DIR}/${CONTAINER_ID}.conmon.pid
declare PID=''
function __run() {
	debug " + podman run ${ARGS[*]}"
	local I
	for I in "${ARGS[@]}"; do
		debug "  :: ${I}"
	done

	get_service_timeout
	expand_timeout "${SERVICE_START_TIMEOUT}"

	sdnotify --status="run main process..."
	podman run "${ARGS[@]}" </dev/null &
	debug "   podman forked"
	sleep .5 || true
	local -i I=10
	while [[ ${I} -gt 0 ]]; do
		I="${I} - 1"
		if [[ -e ${PIDFile} ]]; then
			PID=$(<"${PIDFile}")
			debug "Conmon PID: ${PID}"
			return
		fi
		debug "   wait for conmon create its pid file (${I}/10)"
		sleep 1
	done

	die "Fatal: podman not create pid file: ${PIDFile}"
}
