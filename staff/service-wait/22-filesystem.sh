#!/usr/bin/env bash
set -Eeuo pipefail

function ensure_mounts() {
	local I
	for I; do
		if ! [[ -e ${I} ]]; then
			debug "create missing folder: ${I}"
			/usr/bin/mkdir -p "${I}" || critical_die "can not ensure exists: ${I}"
		fi
	done

	if [[ ${UID} -eq 0 && -n ${SHARED_SOCKET_PATH-} ]]; then
		chmod 0777 "${SHARED_SOCKET_PATH}"
	fi
}
