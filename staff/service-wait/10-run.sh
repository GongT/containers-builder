declare -i SERVICE_START_TIMEOUT_SEC=0
function timespan_to_us() {
	if [[ $1 == infinitiy ]]; then
		echo '0'
	fi
	if ! systemd-analyze timespan "$1" | grep 'μs' | sed 's/.*://g'; then
		echo '0'
	fi
}
function get_service_timeout() {
	if [[ ${SERVICE_START_TIMEOUT_SEC} -ne 0 ]]; then
		return
	fi

	local SPAN
	SPAN=$(systemctl show "${CURRENT_SYSTEMD_UNIT_NAME}" --property=TimeoutStartUSec --value)
	SERVICE_START_TIMEOUT_SEC=$(timespan_to_us "${SPAN}")
}

function __podman_run_container() {
	debug " + podman run$(printf ' %q' "${ARGS[@]}")"
	local I
	for I in "${ARGS[@]}"; do
		debug "  :: ${I}"
	done

	get_service_timeout

	sdnotify "--status=run main process" "EXTEND_TIMEOUT_USEC=${SERVICE_START_TIMEOUT_SEC}"
	trap - EXIT
	exec podman run "${ARGS[@]}"
}

function wait_for_pid_and_notify() {
	local -r PIDFile=$(mktemp --dry-run "/tmp/wait.${CONTAINER_ID}.conmon.XXXX.pid")
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

	echo "pidfile seen at $PIDFile, pid=$PID"
	sdnotify "--pid=${PID}" "--status=conmon started"
}
