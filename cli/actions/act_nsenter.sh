#!/usr/bin/env bash

function do_nsenter() {
	if [[ $# -eq 0 ]]; then
		die "missing arguments"
	fi

	TARGET="$1"
	shift

	if [[ $# -eq 0 ]]; then
		set -- --net --pid /bin/bash
	fi

	local SERVICE_FULL_NAME=$(systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "$TARGET" | grep -E '(running|activating)' | awk '{print $1}' | head -n1)
	if [[ $SERVICE_FULL_NAME ]]; then
		TARGET=$(get_container_by_service "$SERVICE_FULL_NAME")
		PID=$(podman container inspect --format '{{.State.Pid}}' "$TARGET")
		echo -e " + nsenter --target \e[38;5;11m$PID\e[0m $*"
		exec nsenter --target "$PID" "$@"
	else
		systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "$TARGET"
		die "target service ($TARGET) is not exists or not running"
	fi
}
