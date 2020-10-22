#!/usr/bin/env bash
set -Eeuo pipefail

declare -r PIDFile=/run/$CONTAINER_ID.conmon.pid
declare PID=''
function __run() {
	debug " + podman run ${ARGS[*]}"
	local I
	for I in "${ARGS[@]}"; do
		debug "  :: $I"
	done

	podman run "${ARGS[@]}" </dev/null &
	debug "   podman forked"
	sleep .5 || true
	local -i I=10
	while [[ $I -gt 0 ]]; do
		I="$I - 1"
		if [[ -e $PIDFile ]]; then
			PID=$(<"$PIDFile")
			debug "Conmon PID: $PID"
			return
		fi
		debug "   wait for conmon create its pid file ($I/10)"
		sleep 1
	done

	die "Fatal: podman not create pid file: $PIDFile"
}
