#!/usr/bin/env bash
set -Eeuo pipefail

function self_journal() {
	debug "journalctl _SYSTEMD_INVOCATION_ID=${INVOCATION_ID} -f"
	journalctl "_SYSTEMD_INVOCATION_ID=${INVOCATION_ID}" -f 2>&1
}

declare -xr __NOTIFYSOCKET=${NOTIFY_SOCKET-}
function load_sdnotify() {
	if [[ ${NOTIFY_SOCKET+found} == found ]]; then
		echo "[SDNOTIFY] hide socket from podman"
		unset NOTIFY_SOCKET

		function sdnotify() {
			echo "[SDNOTIFY] $*" >&2
			NOTIFY_SOCKET="${__NOTIFYSOCKET}" systemd-notify "$@"
		}
	else
		echo "[SDNOTIFY] disabled"
		function sdnotify() {
			echo "[SDNOTIFY] (disabled) $*" >&2
		}
	fi
}
function expand_timeout() {
	if [[ $1 -gt 0 ]]; then
		sdnotify "EXTEND_TIMEOUT_USEC=$1"
	fi
}
function expand_timeout_seconds() {
	if [[ $1 -gt 0 ]]; then
		sdnotify "EXTEND_TIMEOUT_USEC=$(($1 * 1000000))"
	fi
}

function startup_done() {
	local -i PID
	if [[ -e ${PIDFile} ]]; then
		PID=$(<"${PIDFile}")
		debug "pidfile seen at $PIDFile, pid=$PID"
	else
		critical_die "should success but PIDFile not found."
	fi

	sdnotify --ready --status=ok "--pid=$PID"
	debug "Finish, Ok."
	sleep 2
	exit 0
}
function systemctl() {
	if [[ -z ${XDG_RUNTIME_DIR-} ]] || [[ $XDG_RUNTIME_DIR == */0 ]]; then
		/usr/bin/systemctl "$@"
	else
		/usr/bin/systemctl --user "$@"
	fi
}
