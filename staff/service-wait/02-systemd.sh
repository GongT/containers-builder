#!/usr/bin/env bash
set -Eeuo pipefail

function self_journal() {
	debug "journalctl _SYSTEMD_INVOCATION_ID=${INVOCATION_ID} -f"
	journalctl "_SYSTEMD_INVOCATION_ID=${INVOCATION_ID}" -f 2>&1
}

declare -xr __NOTIFYSOCKET=${NOTIFY_SOCKET-}
function load_sdnotify() {
	if [[ ${NOTIFY_SOCKET+found} == found ]]; then
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
	sdnotify --ready --status=ok
	debug "Finish, Ok."
	sleep 10
	exit 0
}
function systemctl() {
	if [[ -z ${XDG_RUNTIME_DIR-} ]] || [[ $XDG_RUNTIME_DIR == */0 ]]; then
		/usr/bin/systemctl "$@"
	else
		/usr/bin/systemctl --user "$@"
	fi
}

declare -i SERVICE_START_TIMEOUT=0
function get_service_property() {
	systemctl show "${CURRENT_SYSTEMD_UNIT_NAME}" "--property=$1" --value
}
