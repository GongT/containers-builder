#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_port() {
	local -r PROTOCOL=$1 PORT=$2

	while ! INNER_PID=$(podman container inspect -f '{{.State.Pid}}'); do
		sleep 2
	done

	debug "container init pid is ${INNER_PID}"

	while ! nsenter --user --net --target "${INNER_PID}" ss --listening "--$PROTOCOL" --numeric | grep -q ":${PORT} "; do
		sleep 2
	done
	debug "port has opened for listening"
}
