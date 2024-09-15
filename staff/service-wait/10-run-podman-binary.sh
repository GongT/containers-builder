declare -i SERVICE_START_TIMEOUT_SEC=0
function get_service_timeout() {
	if [[ ${SERVICE_START_TIMEOUT_SEC} -ne 0 ]]; then
		return
	fi

	local SPAN
	SPAN=$(get_service_property TimeoutStartUSec)
	SERVICE_START_TIMEOUT_SEC=$(timespan_seconds "${SPAN}")
}

function podman_run_container() {
	debug " + podman run$(printf ' %q' "${ARGS[@]}")"
	local I
	for I in "${ARGS[@]}"; do
		debug "  :: ${I}"
	done

	get_service_timeout

	sdnotify "--status=run main process" "EXTEND_TIMEOUT_USEC=$((SERVICE_START_TIMEOUT_SEC * microsecond_unit))"
	trap - EXIT
	exec podman run "${ARGS[@]}"
}

function wait_for_pid_and_notify() {
	local -r PIDFile="$(mktemp --dry-run --tmpdir "${CONTAINER_ID}.conmon.XXXXX.pid")"
	add_run_argument "--conmon-pidfile=${PIDFile}"

	rm -f "${PIDFile}"
	__pid_waiter_thread &
}

function __pid_waiter_thread() {
	while ! [[ -e ${PIDFile} ]]; do
		sleep 1
	done
	local PID
	PID=$(<"${PIDFile}")
	rm -f "${PIDFile}"

	echo "pidfile seen at $PIDFile, pid=$PID"
	sdnotify "--pid=${PID}" "--status=conmon started"
}

function wait_for_conmon_start() {
	local MPID BIN
	while true; do
		MPID=$(get_service_property "MainPID")
		if [[ -e "/proc/${MPID}/cmdline" ]]; then
			BIN=$(awk -F '\0' '{print $1}' "/proc/${MPID}/cmdline")
			if [[ $(basename "${BIN}") == conmon ]]; then
				break
			fi
		fi

		sleep 1
	done

	declare -igr PID=${MPID}
}
