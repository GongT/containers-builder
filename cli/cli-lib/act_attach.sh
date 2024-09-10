#!/usr/bin/env bash

function do_attach() {
	if [[ $# -eq 0 ]]; then
		die "missing arguments"
	fi

	TARGET="$1"
	shift
	if [[ $# -gt 0 ]]; then
		CMD="$1"
		shift
	else
		CMD="sh"
	fi

	local SERVICE_FULL_NAME=$(systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "$TARGET" | grep -E '(running|activating)' | awk '{print $1}' | head -n1)
	if [[ $SERVICE_FULL_NAME ]]; then
		TARGET=$(get_container_by_service "$SERVICE_FULL_NAME")
		echo -e " + podman exec -it \e[38;5;11m$TARGET\e[0m $CMD $*" >&2
		exec podman exec -it "$TARGET" "$CMD" "$@"
	else
		systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "$TARGET"
		die "target service ($TARGET) is not exists or not running"
	fi
}
