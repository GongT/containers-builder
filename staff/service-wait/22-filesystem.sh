function ensure_mounts() {
	local I
	for I in "${PREPARE_FOLDERS[@]}"; do
		if [[ ! -e ${I} ]]; then
			debug "create missing folder: ${I}"
			/usr/bin/mkdir -p "${I}" || critical_die "can not ensure exists: ${I}"
		fi
	done

	if [[ ${UID} -eq 0 && -n ${SHARED_SOCKET_PATH-} ]]; then
		chmod 0777 "${SHARED_SOCKET_PATH}"
	fi
}

function remove_old_socks() {
	mkdir --mode 0777 -p "${SHARED_SOCKET_PATH}"
	if [[ ${#PROVIDED_SOCKETS[@]} -gt 0 ]]; then
		cd "${SHARED_SOCKET_PATH}"
		rm -f "${PROVIDED_SOCKETS[@]}" || true
	fi
}
