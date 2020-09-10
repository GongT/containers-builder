#!/usr/bin/env bash

set -Eeuo pipefail
ARGS=("--attach=stdin,stdout,stderr")
# ARGS+=("--log-level=debug")
declare -r PIDFile=/run/$CONTAINER_ID.conmon.pid

function debug() {
	echo "{wait-run} $*" >&2
}
function critical_die() {
	debug "$*"
	exit 233
}
function die() {
	debug "$*"
	exit 1
}

function __run() {
	debug " + podman run ${ARGS[*]}"
	podman run "${ARGS[@]}" < /dev/null &
	debug "   podman forked"
	sleep .5 || true
	local -i I=10
	while [[ $I -gt 0 ]]; do
		I="$I - 1"
		if [[ -e "$PIDFile" ]]; then
			debug "Conmon PID: $(< "$PIDFile")"
			return
		fi
		debug "   wait for conmon create its pid file ($I/10)"
		sleep 1
	done

	die "Fatal: podman not create pid file: $PIDFile"
}

function self_journal() {
	journalctl "_SYSTEMD_INVOCATION_ID=$INVOCATION_ID" -f
}

__NOTIFYSOCKET=
function load_sdnotify() {
	if [[ "${NOTIFY_SOCKET+found}" = found ]]; then
		echo "[SDNOTIFY] using socket: $NOTIFY_SOCKET"
		__NOTIFYSOCKET="$NOTIFY_SOCKET"

		echo "[SDNOTIFY] hide socket from podman"
		unset NOTIFY_SOCKET

		function sdnotify() {
			if [[ "$*" != "--status="* ]]; then
				echo "[SDNOTIFY] ($__NOTIFYSOCKET) ===== $*" >&2
			fi
			NOTIFY_SOCKET="$__NOTIFYSOCKET" systemd-notify "$@"
		}
		sdnotify --status=prestart
	else
		echo "[SDNOTIFY] disabled"
		function sdnotify() {
			echo "[SDNOTIFY] (disabled) ===== $*" >&2
		}
	fi
}

LPID=""
LCID=""
LSTAT=""
function get_container() {
	local DATA=()
	mapfile -t DATA < <(podman inspect --type container --format $'{{.State.ConmonPid}}\n{{.Id}}\n{{.State.Status}}' "$CONTAINER_ID" 2> /dev/null || true)
	LPID=${DATA[0]:-}
	LCID=${DATA[1]:-}
	LSTAT=${DATA[2]:-}
}

function ensure_container_not_running() {
	get_container
	if [[ ! "$LCID" ]]; then
		debug "good, no old container"
		return
	fi
	debug "-- old container exists --" >&2
	debug "Conmon PID: $LPID" >&2
	debug "Container ID: $LCID" >&2
	debug "State: $LSTAT" >&2
	if [[ "$LSTAT" == "running" ]]; then
		if [[ "$KILL_IF_TIMEOUT" = yes ]]; then
			podman stop "$CONTAINER_ID" || true
		else
			podman stop --time 9999 "$CONTAINER_ID" || true
		fi
	else
		podman rm -f "$CONTAINER_ID" || true
	fi

	get_container
	if [[ ! "$LCID" ]]; then
		debug "good, old container removed."
		return
	fi
	debug "-- old container still exists --" >&2
	exit 233
}

function find_bridge_ip() {
	podman network inspect podman | grep -oE '"gateway": ".+",?$' | sed 's/"gateway": "\(.*\)".*/\1/g'
}

function ensure_mounts() {
	local I
	for I; do
		if ! [[ -e "$I" ]]; then
			/usr/bin/mkdir -p "$I" || critical_die "can not ensure exists: $I"
		fi
	done
}

function make_arguments() {
	local HOST_IP

	if [[ "$NETWORK_TYPE" == "host" ]]; then
		HOST_IP="127.0.0.1"
	elif [[ "$NETWORK_TYPE" == "bridge" ]]; then
		HOST_IP=$(find_bridge_ip)
		if ! [[ "$HOST_IP" ]]; then
			critical_die "Can not get information about default podman network (podman0), podman configure failed."
		fi
	else
		HOST_IP=""
	fi

	echo "Local host access address: $HOST_IP"
	ARGS+=("--env=HOSTIP=$HOST_IP")

	for i; do
		if [[ "$i" == "--dns=h.o.s.t" ]]; then
			if ! [[ "$HOST_IP" ]]; then
				critical_die "Try to use h.o.s.t when network type is $NETWORK_TYPE, this is currently not supported."
			fi
			ARGS+=("--dns=$HOST_IP")
		else
			ARGS+=("$i")
		fi
	done
}

function wait_by_sleep() {
	__run

	local PID
	PID=$(< "$PIDFile")

	local -i I=$WAIT_TIME
	while [[ $I -gt 0 ]]; do
		I="$I - 1"
		if [[ "$(readlink "/proc/$PID/exe")" != /usr/bin/conmon ]]; then
			debug "Failed wait container $CONTAINER_ID to stable." >&2
			sdnotify --status="gone"
			exit 1
		fi
		debug "$I." >&2
		sdnotify --status="wait:$I/$WAIT_TIME"
		sleep 1
	done
	debug "Container still running."
}

function wait_by_output() {
	sdnotify --status="wait:output"

	__run

	local TMP=$(mktemp -u)
	mkfifo "$TMP"
	self_journal &> "$TMP" &
	while read -r line; do
		sdnotify "--status=EXTEND_TIMEOUT_USEC=$((10 * 1000 * 1000))"
		if echo "$line" | grep -qE "$WAIT_OUTPUT"; then
			debug "== ---- output found ---- =="
			break
		fi
	done < "$TMP"
	rm "$TMP"
}

function wait_by_create_file() {
	if podman volume inspect ACTIVE_FILE 2>&1 | grep -q "no such volume"; then
		podman volume create ACTIVE_FILE
	fi
	ACTIVE_FILE_ROOT=$(podman volume inspect ACTIVE_FILE -f "{{.Mountpoint}}")
	ACTIVE_FILE_ABS="$ACTIVE_FILE_ROOT/$ACTIVE_FILE"

	sdnotify --status="wait:activefile"
	rm -f "$ACTIVE_FILE_ABS"

	__run

	debug "    file: $ACTIVE_FILE_ROOT/$ACTIVE_FILE"
	while ! [[ -e "$ACTIVE_FILE_ABS" ]]; do
		sleep 1
	done

	debug "== ---- active file created ---- =="

	rm -f "$ACTIVE_FILE_ABS"
}

# function wait_by_udp_ping() {
# }

# function wait_by_named_pipe_ping() {
# }

function main() {
	echo "======================================="
	env
	echo "======================================="

	load_sdnotify

	make_arguments "$@"

	ensure_container_not_running

	debug "Wait container $CONTAINER_ID."

	if [[ -n "$WAIT_TIME" ]]; then
		debug "   method: sleep $WAIT_TIME seconds"
		wait_by_sleep
	elif [[ -n "$WAIT_OUTPUT" ]]; then
		debug "   method: wait output '$WAIT_OUTPUT'"
		wait_by_output
	elif [[ -n "$ACTIVE_FILE" ]]; then
		debug "   method: wait file $ACTIVE_FILE_ABS to exists"
		wait_by_create_file
	else
		debug "   method: none"
	fi

	sdnotify --ready --status="ok"
	debug "Finish, Ok."
	exit 0
}
