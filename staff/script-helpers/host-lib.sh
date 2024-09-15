#!/usr/bin/env bash

declare -xr __NOTIFYSOCKET=${NOTIFY_SOCKET-}
function load_sdnotify() {
	if [[ ${NOTIFY_SOCKET+found} == found ]]; then
		function sdnotify() {
			echo "[SDNOTIFY] $*" >&2
			NOTIFY_SOCKET="${__NOTIFYSOCKET}" systemd-notify "$@"
		}
	else
		function sdnotify() {
			echo "[SDNOTIFY] (disabled) $*" >&2
		}
	fi
}
function hide_sdnotify() {
	unset NOTIFY_SOCKET
}
