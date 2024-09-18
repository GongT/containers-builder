#!/usr/bin/bash

source "../../package/include.sh"

use_normal

TYPE=${1-}
if [[ $TYPE == stop ]]; then
	OUTPUT=$(container_get_status)
	if [[ ${OUTPUT} == "removed" ]]; then
		exit 0
	fi

	info_log "cleanup after exit:"
	if is_running_state "${OUTPUT}"; then
		info_log "  - found running container."
		x podman container stop --ignore "--time=-1" "${CONTAINER_ID}"
	else
		x podman container rm --ignore "--time=-1" "${CONTAINER_ID}"
	fi
	info_log "  * done."
elif [[ $TYPE == kill ]]; then
	OUTPUT=$(container_get_status)
	if [[ ${OUTPUT} == "removed" ]]; then
		exit 0
	fi

	info_log "final cleanup: [killtime=${PODMAN_TIMEOUT_TO_KILL}]"

	if is_running_state "${OUTPUT}"; then
		info_log "  - found running container."
		x podman container stop --ignore "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
	fi

	if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
		sleep 3s
		if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
			info_warn "  - clearing dirty state."
			x podman container rm --ignore --force "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
		else
			exit 0
		fi
	else
		exit 0
	fi

	if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
		info_warn "  - clearing dirty state (tree)."
		x podman container rm --ignore --force --depend "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
	else
		exit 0
	fi

	if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
		die "  * still not able to remove container"
	else
		exit 0
	fi
else
	die "invalid call type"
fi
