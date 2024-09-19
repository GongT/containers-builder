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
	SPAN=$(systemctl show "${UNIT_NAME}" --property=TimeoutStartUSec --value)
	SERVICE_START_TIMEOUT_SEC=$(timespan_to_us "${SPAN}")
}

function __podman_run_container() {
	info_log " + podman run$(printf ' %q' "${PODMAN_EXEC_ARGS[@]}")"
	local I
	for I in "${PODMAN_EXEC_ARGS[@]}"; do
		info_log "  :: ${I}"
	done

	get_service_timeout

	sdnotify "--status=run main process" "EXTEND_TIMEOUT_USEC=${SERVICE_START_TIMEOUT_SEC}"
	trap - EXIT
	exec podman run "${PODMAN_EXEC_ARGS[@]}"
}

function wait_for_pid_and_notify() {
	mkdir --mode 0777 -p '/tmp/service-wait'
	local -r PIDFile=$(mktemp --dry-run "/tmp/service-wait/${CONTAINER_ID}.conmon.XXXX.pid")
	push_engine_param "--conmon-pidfile=${PIDFile}"

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
