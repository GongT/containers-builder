#!/usr/bin/env bash
set -Eeuo pipefail

function service_wait_process() {
	trap - EXIT
	debug "wait container ${CONTAINER_ID}, spec ${START_WAIT_DEFINE}."

	local WAIT_TYPE=${START_WAIT_DEFINE%%:*}
	local WAIT_ARGS=${START_WAIT_DEFINE#*:}

	case "${WAIT_TYPE}" in
	socket)
		wait_by_socket "$WAIT_ARGS"
		;;
	port)
		wait_by_port "${WAIT_ARGS%:*}" "${WAIT_ARGS#*:}"
		;;
	sleep)
		wait_by_sleep "$WAIT_ARGS"
		;;
	output)
		wait_by_output "$WAIT_ARGS"
		;;
	touch)
		wait_by_create_file "$WAIT_ARGS"
		;;
	pass)
		return
		;;
	*)
		# die not work in fact
		critical_die "invalid wait type: ${WAIT_TYPE}"
		;;
	esac

	startup_done
}

function main() {
	detect_image_using_systemd
	load_sdnotify

	add_argument "--name=${CONTAINER_ID}"
	ensure_mounts "${PREPARE_FOLDERS[@]}"

	if [[ $START_WAIT_DEFINE == touch ]]; then
		declare -xr FILE_TO_CHECK="/startup.$RANDOM.signal"
		add_argument "--env=STARTUP_TOUCH=$FILE_TO_CHECK"
	elif [[ $START_WAIT_DEFINE == pass ]]; then
		add_argument "--env=NOTIFYSOCKET=$__NOTIFYSOCKET"
	fi

	make_arguments "$@"

	ensure_container_not_running

	service_wait_process &

	__podman_run_container
}

main "$@"
