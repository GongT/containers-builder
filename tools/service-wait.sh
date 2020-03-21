#!/usr/bin/env bash

set -Eeuo pipefail
ARGS=("$@")

PIDFile=/run/$CONTAINER_ID.conmon.pid

function debug() {
	echo "[wait-run] $*" >&2
}
function die() {
	debug "$*"
	exit 1
}
function __run() {
	debug " + podman ${ARGS[*]}"
	podman "${ARGS[@]}" &
	local I=10
	while [[ $I -gt 0 ]]; do
		I=$(($I - 1))
		if [[ -e "$PIDFile" ]]; then
			debug "Conmon PID: $(<$PIDFile)"
			return
		fi
		debug "   wait pid $I/10"
		sleep 1
	done

	die "Fatal: podman not create pid file: $PIDFile"
}
function sdnotify() {
	if [[ "${NOTIFY_SOCKET+found}" = found ]]; then
		systemd-notify "$@"
	fi
}

debug "Wait container $CONTAINER_ID."
if [[ -n "$WAIT_TIME" ]]; then
	debug "   method: sleep $WAIT_TIME seconds"
	__run
	I=$WAIT_TIME
	while [[ "$I" -gt 0 ]]; do
		I=$(($I - 1))
		if ! podman inspect --type=container "$CONTAINER_ID" &>/dev/null; then
			debug "Failed wait container $CONTAINER_ID to stable." >&2
			sdnotify --status="gone"
			exit 1
		fi
		debug "$I." >&2
		sdnotify --status="wait:$I"
		sleep 1
	done
	debug "Container still running."
elif [[ -n "$WAIT_OUTPUT" ]]; then
	debug "   method: wait output '$WAIT_OUTPUT'"
	__run
	(
		IN=/tmp/$RANDOM.in.fifo
		mkfifo $IN
		podman attach --detach-keys=q --no-stdin=true --sig-proxy=false "$CONTAINER_ID" &>$IN &
		PID=$!
		debug "PID=$PID"
		while read line; do
			if echo "$line" | grep -qE "$WAIT_OUTPUT"; then
				debug "output found"
				kill -SIGKILL $PID
				exit 0
			fi
		done <$IN
	) || die "Can not read output!"
	debug "got string"
elif [[ -n "$ACTIVE_FILE" ]]; then
	if podman volume inspect ACTIVE_FILE 2>&1 | grep -q "no such volume"; then
		podman volume create ACTIVE_FILE
	fi
	ACTIVE_FILE_ROOT=$(podman volume inspect ACTIVE_FILE -f "{{.Mountpoint}}")
	ACTIVE_FILE_ABS="$ACTIVE_FILE_ROOT/$ACTIVE_FILE"

	debug "   method: wait file $ACTIVE_FILE_ABS to exists"
	sdnotify --status="wait:active"
	rm -f "$ACTIVE_FILE_ABS"

	__run

	while ! [[ -e "$ACTIVE_FILE_ABS" ]]; do
		sleep 1
	done

	debug "got file"
else
	debug "   method: none"
fi

sdnotify --ready --status="ok"
debug "Conmon PID: $(<$PIDFile)"
