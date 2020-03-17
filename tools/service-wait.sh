#!/usr/bin/env bash

set -Eeuo pipefail
ARGS=("$@")

function __run() {
	echo podman "${ARGS[@]}"
	podman "${ARGS[@]}" &
	PIDFile=/run/$CONTAINER_ID.conmon.pid
	sleep 1
	echo "Conmon PID: $(<$PIDFile)"
}
function sdnotify() {
	if [[ "${NOTIFY_SOCKET+found}" = found ]]; then
		systemd-notify "$@"
	fi
}

echo "[wait-run] Wait container $CONTAINER_ID."
if [[ -n "$WAIT_TIME" ]]; then
	echo "[wait-run]    method: sleep $WAIT_TIME seconds"
	__run
	I=$WAIT_TIME
	while [[ "$I" -gt 0 ]]; do
		I=$(($I - 1))
		if ! podman inspect --type=container "$CONTAINER_ID" &>/dev/null; then
			echo "[wait-run] Failed wait container $CONTAINER_ID to stable." >&2
			sdnotify --status="gone"
			exit 1
		fi
		echo "[wait-run] $I." >&2
		sdnotify --status="wait:$I"
		sleep 1
	done
	echo "[wait-run] Container still running."
elif [[ -n "$WAIT_OUTPUT" ]]; then
	echo "[wait-run]    method: wait output '$WAIT_OUTPUT'"
	__run
	(
		IN=/tmp/$RANDOM.in.fifo
		mkfifo $IN
		podman attach --detach-keys=q --no-stdin=true --sig-proxy=false "$CONTAINER_ID" &>$IN &
		PID=$!
		echo "PID=$PID"
		while read line; do
			if echo "$line" | grep -qE "$WAIT_OUTPUT"; then
				echo "[wait-run] output found"
				kill -SIGKILL $PID
				exit 0
			fi
		done <$IN
		true
	)
	echo "[wait-run] got string"
elif [[ -n "$ACTIVE_FILE" ]]; then
	if podman volume inspect ACTIVE_FILE 2>&1 | grep -q "no such volume" ; then
		podman volume create ACTIVE_FILE
	fi
	ACTIVE_FILE_ROOT=$(podman volume inspect ACTIVE_FILE -f "{{.Mountpoint}}")
	ACTIVE_FILE_ABS="$ACTIVE_FILE_ROOT/$ACTIVE_FILE"

	echo "[wait-run]    method: wait file $ACTIVE_FILE_ABS to exists"
	sdnotify --status="wait:active"
	rm -f "$ACTIVE_FILE_ABS"

	__run

	while ! [[ -e "$ACTIVE_FILE_ABS" ]]; do
		sleep 1
	done

	echo "[wait-run] got file"
else
	echo "[wait-run]    method: none"
fi

sdnotify --ready --status="ok"
echo "[wait-run] Conmon PID: $(<$PIDFile)"
