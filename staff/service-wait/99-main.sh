#!/usr/bin/env bash
set -Eeuo pipefail

function core_switch() {
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
	healthy) ;; # do nothing
	pass) ;;    # do nothing
	*)
		sdnotify "--status=startup timeout"
		echo "invalid wait type: ${WAIT_TYPE}" >&2
		return 1
		;;
	esac
}

function service_wait_process() {
	trap - EXIT
	debug "wait container ${CONTAINER_ID}, spec ${START_WAIT_DEFINE}."

	local WAIT_TYPE=${START_WAIT_DEFINE%%:*}
	local WAIT_ARGS=${START_WAIT_DEFINE#*:}

	if core_switch; then
		startup_done
	else
		debug "failed wait container '${CONTAINER_ID}' to stable running."

		sdnotify --stopping "wait fail"

		local PID
		PID=$(get_service_property "MainPID")
		if [[ ${PID} -gt 0 ]]; then
			echo "send signal to podman container ${PID}"
			kill -s sigterm "${PID}"
		fi
	fi
}

function main() {
	detect_image_using_systemd
	load_sdnotify

	add_run_argument "--name=${CONTAINER_ID}"
	ensure_mounts "${PREPARE_FOLDERS[@]}"

	if [[ $START_WAIT_DEFINE == auto ]]; then
		if is_image_has_healthcheck; then
			START_WAIT_DEFINE=healthy
		elif is_image_using_systemd; then
			START_WAIT_DEFINE=pass
		else
			START_WAIT_DEFINE=sleep:10
		fi
	fi

	if [[ $START_WAIT_DEFINE == touch ]]; then
		declare -xr FILE_TO_CHECK="/startup.$RANDOM.signal"
		add_run_argument "--env=STARTUP_TOUCH=$FILE_TO_CHECK"
	fi

	if [[ $START_WAIT_DEFINE == pass ]]; then
		add_run_argument "--sdnotify=container"
	elif [[ $START_WAIT_DEFINE == healthy ]]; then
		add_run_argument "--sdnotify=healthy"
	else
		wait_for_pid_and_notify
		add_run_argument "--sdnotify=ignore"
	fi

	# echo "[SDNOTIFY] hide socket from podman: $NOTIFY_SOCKET"
	# unset NOTIFY_SOCKET

	make_arguments "$@"

	ensure_container_not_running

	service_wait_process &

	__podman_run_container
}

main "$@"
