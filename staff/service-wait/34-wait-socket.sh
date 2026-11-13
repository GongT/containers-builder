function wait_by_socket() {
	local -r NAME="${PROVIDED_SOCKETS[0]}"
	local FILEABS
	FILEABS="${SHARED_SOCKET_PATH}/${CONTAINER_ID}"
	if [[ -n ${NAME} ]]; then
		FILEABS+=".${NAME}"
	fi
	FILEABS+=".sock"

	info_log "等待容器创建共享 socket 文件 ${FILEABS}"
	sdnotify --status="等待共享 socket 文件..."
	while ! socat -u OPEN:/dev/null "UNIX-CONNECT:${FILEABS}"; do
		sleep 5
	done
	service_wait_success
}
