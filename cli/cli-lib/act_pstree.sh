#!/usr/bin/env bash

function do_pstree() {
	if [[ $# -eq 0 ]]; then
		die "missing arguments"
	fi

	TARGET="$1"
	shift

	if [[ $# -eq 0 ]]; then
		set -- -a -A -n -p -T -U
	fi

	local SERVICE_FULL_NAME=$(systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "$TARGET" | grep -E '(running|activating)' | awk '{print $1}' | head -n1)
	if [[ $SERVICE_FULL_NAME ]]; then
		TARGET=$(get_container_by_service "$SERVICE_FULL_NAME")
		CPID=$(podman inspect --format '{{.State.ConmonPid}}' "$TARGET")
		echo -e " + pstree $* \e[38;5;11m$CPID\e[0m"
		exec pstree "$@" "$CPID"
	else
		systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "$TARGET"
		die "target service ($TARGET) is not exists or not running"
	fi
}
