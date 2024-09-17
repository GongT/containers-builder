#!/usr/bin/bash

source "../../package/include.sh"

use_normal

OUTPUT="$(podman container inspect -f '{{.State.Status}}' "${CONTAINER_ID}" 2>&1)"
if [[ ${OUTPUT} == *"no such container"* ]]; then
	info_note "greate! no container need to kill."
	exit 0
fi

if [[ ${OUTPUT} == "running" ]]; then
	info_log "found running container."
	x podman stop --ignore "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
fi

if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
	sleep 3s
	if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
		info_warn "clearing dirty state."
		x podman rm --ignore --force "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
	else
		exit 0
	fi
else
	exit 0
fi

if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
	info_warn "clearing dirty state (tree)."
	x podman rm --ignore --force --depend "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
else
	exit 0
fi

if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
	die "still not able to remove container"
else
	exit 0
fi
