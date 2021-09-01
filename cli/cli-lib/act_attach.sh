#!/usr/bin/env bash

function do_attach() {
	if [[ $# -eq 0 ]]; then
		die ""
	fi

	TARGET="$1"
	shift
	if [[ $# -gt 0 ]]; then
		CMD="$1"
		shift
	else
		CMD="sh"
	fi

	if systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep running | awk '{print $1}' | grep -q "$TARGET"; then
		echo -e " + podman exec -it \e[38;5;11m$TARGET\e[0m $CMD $*"
		exec podman exec -it "$TARGET" "$CMD" "$@"
	else
		die "target service ($TARGET) is not exists or not running"
	fi
}
