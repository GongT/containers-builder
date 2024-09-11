#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_port() {
	local -r PROTOCOL=$1 NAME=$2 FILE
	FILE="${SHARED_SOCKET_PATH}/${NAME}"

	debug "wait socket ${FILE}"
	while ! socat -u OPEN:/dev/null "UNIX-CONNECT:${FILE}"; do
		sleep 5
	done
}
