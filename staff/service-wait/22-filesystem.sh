function ensure_mounts() {
	local I
	for I in "${PREPARE_FOLDERS[@]}"; do
		if [[ ! -e ${I} ]]; then
			info_log "创建缺失的宿主机文件夹: ${I}"
			/usr/bin/mkdir -p "${I}" || critical_die "无法确保存在: ${I}"
		fi
	done

	if [[ ${UID} -eq 0 && -n ${SHARED_SOCKET_PATH-} ]]; then
		chmod 0777 "${SHARED_SOCKET_PATH}"
	fi
}

function remove_old_socks() {
	mkdir -p "${SHARED_SOCKET_PATH}"
	chmod 0777 "${SHARED_SOCKET_PATH}"
	if [[ ${#PROVIDED_SOCKETS[@]} -gt 0 ]]; then
		rm -f "${SHARED_SOCKET_PATH}/${CONTAINER_ID}."* || true
	fi
}
