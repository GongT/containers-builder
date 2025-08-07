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

	function print_err() {
		systemctl list-units '*.pod@.service' '*.pod.service' --no-pager --no-legend | grep "${TARGET}" || true
		die "target service (${TARGET}) is not exists or not running"
	}

	CONTAINER=$(find_one_container_by_hint "${TARGET}" || print_err)
	PID=$(podman container inspect --format '{{.State.Pid}}' "${CONTAINER}" || print_err)
	echo -e " + nsenter --target \e[38;5;11m${PID}\e[0m $*"
	exec nsenter --target "${PID}" "$@"
}
