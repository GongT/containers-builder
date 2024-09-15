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
		info_log "good, no old container"
		return
	fi
	info_log "-- old container exists --" >&2
	sdnotify "--status=killing old container"
	expand_timeout_seconds "30"

	while true; do
		info_log "Conmon PID: ${LPID}" >&2
		info_log "Container ID: ${LCID}" >&2
		info_log "State: ${LSTAT}" >&2
		if [[ ${LSTAT} == "running" ]]; then
			if [[ ${ALLOW_FORCE_KILL} == yes ]]; then
				podman stop "${CONTAINER_ID}" || true
			else
				podman stop --time 9999 "${CONTAINER_ID}" || true
			fi
		else
			podman ps -a | tail -n +2 \
				| (grep -v Up || [[ $? == 1 ]]) \
				| awk '{print $1}' \
				| xargs --no-run-if-empty --verbose --no-run-if-empty podman rm || true
		fi

		get_container
		if [[ -z ${LCID} ]]; then
			info_log "good, old container removed."
			return
		fi

		info_log "-- old container still exists --" >&2
	done

	critical_die "failed delete old container"
}
