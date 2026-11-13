function wait_by_port() {
	local -r PORT_DEFINE="$1"
	local -r PORT=${PORT_DEFINE%/*} PROTOCOL=${PORT_DEFINE#*/}

	while ! INNER_PID=$(podman container inspect -f '{{.State.Pid}}' "${CONTAINER_ID}"); do
		sleep 2
	done

	info_log "容器已初始化，PID 是 ${INNER_PID}"
	sdnotify --status="等待端口打开..."

	while ! nsenter --user --net --target "${INNER_PID}" ss --listening "--$PROTOCOL" --numeric | grep -q ":${PORT} "; do
		sleep 2
	done
	info_log "${PROTOCOL} 端口 ${PORT} 已开始监听"
	service_wait_success
}
