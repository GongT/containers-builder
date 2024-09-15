function wait_by_socket() {
	local -r NAME="${PROVIDED_SOCKETS[0]}"
	local FILEABS
	FILEABS="${SHARED_SOCKET_PATH}/${NAME}"

	info_log "wait socket ${FILEABS}"
	while ! socat -u OPEN:/dev/null "UNIX-CONNECT:${FILEABS}"; do
		sleep 5
	done
	service_wait_success
}
