function wait_by_create_file() {
	local ACTIVE_FILE=$1 ACTIVE_FILE_ABS ROOT
	wait_for_conmon_start

	ROOT=$(podman unshare podman mount "${CONTAINER_ID}")
	ACTIVE_FILE_ABS="${ROOT}/${ACTIVE_FILE}"

	info_log "等待容器内文件出现: ${ACTIVE_FILE_ABS}"
	sdnotify --status="等待创建文件..."
	while ! [[ -e ${ACTIVE_FILE_ABS} ]]; do
		sleep 1
	done

	info_log "== ---- 容器内文件已创建 ---- =="
	service_wait_success

	rm -f "${ACTIVE_FILE_ABS}" || true

	podman unshare podman unmount "${CONTAINER_ID}"
}
