#!/usr/bin/env bash
set -Eeuo pipefail

function main() {
	echo "======================================="
	pwd
	env
	echo "======================================="

	ensure_mounts "${PREP_FOLDERS_INS[@]}"
	podman volume prune -f &>/dev/null || true

	load_sdnotify

	make_arguments "$@"

	ensure_container_not_running

	debug "Wait container $CONTAINER_ID."

	if [[ -n $WAIT_TIME ]]; then
		debug "   method: sleep $WAIT_TIME seconds"
		wait_by_sleep
	elif [[ -n $WAIT_OUTPUT ]]; then
		debug "   method: wait output [${WAIT_OUTPUT:0:1}][${WAIT_OUTPUT:1}]"
		wait_by_output
		exit 1 # never return here
	elif [[ -n $ACTIVE_FILE ]]; then
		debug "   method: wait file $ACTIVE_FILE_ABS to exists"
		wait_by_create_file
	else
		debug "   method: none"
	fi

	startup_done
}

main "$@"
