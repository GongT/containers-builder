LPID=""
LCID=""
LSTAT=""
function get_container() {
	local DATA=()
	mapfile -t DATA < <(podman container inspect --format $'{{.State.ConmonPid}}\n{{.Id}}\n{{.State.Status}}' "${CONTAINER_ID}" 2>/dev/null || true)
	LPID=${DATA[0]-}
	LCID=${DATA[1]-}
	LSTAT=${DATA[2]-}
}

function ensure_container_not_running() {
	get_container
	if [[ -z ${LCID} ]]; then
		info_log "很好, 没有旧容器"
		return
	fi
	info_log "-- 发现旧容器 --" >&2
	sdnotify "--status=删除旧容器"
	expand_timeout_seconds "30"

	while true; do
		info_log "Conmon PID: ${LPID}" >&2
		info_log "容器 ID: ${LCID}" >&2
		info_log "状态: ${LSTAT}" >&2
		if [[ ${LSTAT} == "running" ]]; then
			if [[ ${ALLOW_FORCE_KILL} == yes ]]; then
				podman stop "${CONTAINER_ID}" || true
			else
				podman stop --time 9999 "${CONTAINER_ID}" || true
			fi
		else
			podman ps -a | tail -n +2 \
				| grep_safe -v Up \
				| awk '{print $1}' \
				| xargs --no-run-if-empty --verbose --no-run-if-empty podman rm || true
		fi

		get_container
		if [[ -z ${LCID} ]]; then
			info_log "  * 旧容器已删除."
			return
		fi

		info_log "-- 旧容器仍然存在 --" >&2
	done

	critical_die "删除旧容器失败，无法继续"
}
