#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_create_file() {
	local ACTIVE_FILE=$1 ACTIVE_FILE_ABS ROOT
	wait_for_conmon_start

	ROOT=$(podman unshare podman mount "${CONTAINER_ID}")
	ACTIVE_FILE_ABS="${ROOT}/${ACTIVE_FILE}"

	debug "file: ${ACTIVE_FILE_ABS}"
	while ! [[ -e ${ACTIVE_FILE_ABS} ]]; do
		sleep 1
	done

	debug "== ---- active file created ---- =="
	service_wait_success

	rm -f "${ACTIVE_FILE_ABS}" || true

	podman unshare podman unmount "${CONTAINER_ID}"
}
