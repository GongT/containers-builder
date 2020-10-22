#!/usr/bin/env bash
set -Eeuo pipefail

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
	while ! [[ -e $ACTIVE_FILE_ABS ]]; do
		sleep 1
	done

	debug "== ---- active file created ---- =="

	rm -f "$ACTIVE_FILE_ABS"
}
