#!/usr/bin/env bash
set -Eeuo pipefail

function self_journal() {
	debug "journalctl _SYSTEMD_INVOCATION_ID=$INVOCATION_ID -f"
	journalctl "_SYSTEMD_INVOCATION_ID=$INVOCATION_ID" -f 2>&1
}

__NOTIFYSOCKET=
function load_sdnotify() {
	if [[ ${NOTIFY_SOCKET+found} == found ]]; then
		echo "[SDNOTIFY] using socket: $NOTIFY_SOCKET"
		__NOTIFYSOCKET="$NOTIFY_SOCKET"

		echo "[SDNOTIFY] hide socket from podman"
		unset NOTIFY_SOCKET

		function sdnotify() {
			if [[ $* != "--status="* ]] && [[ $* != "EXTEND_TIMEOUT_USEC="* ]]; then
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

function startup_done() {
	sdnotify --ready --status="ok"
	debug "Finish, Ok."
	sleep 2
	exit 0
}
