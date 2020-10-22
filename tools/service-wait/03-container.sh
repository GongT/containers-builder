#!/usr/bin/env bash
set -Eeuo pipefail

LPID=""
LCID=""
LSTAT=""
function get_container() {
	local DATA=()
	mapfile -t DATA < <(podman inspect --type container --format $'{{.State.ConmonPid}}\n{{.Id}}\n{{.State.Status}}' "$CONTAINER_ID" 2>/dev/null || true)
	LPID=${DATA[0]:-}
	LCID=${DATA[1]:-}
	LSTAT=${DATA[2]:-}
}

function ensure_container_not_running() {
	get_container
	if [[ ! $LCID ]]; then
		debug "good, no old container"
		return
	fi
	debug "-- old container exists --" >&2
	debug "Conmon PID: $LPID" >&2
	debug "Container ID: $LCID" >&2
	debug "State: $LSTAT" >&2
	if [[ $LSTAT == "running" ]]; then
		if [[ $KILL_IF_TIMEOUT == yes ]]; then
			podman stop "$CONTAINER_ID" || true
		else
			podman stop --time 9999 "$CONTAINER_ID" || true
		fi
	else
		podman rm -f "$CONTAINER_ID" || true
	fi

	get_container
	if [[ ! $LCID ]]; then
		debug "good, old container removed."
		return
	fi
	debug "-- old container still exists --" >&2
	exit 233
}
