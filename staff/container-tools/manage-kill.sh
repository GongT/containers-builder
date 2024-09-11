#!/usr/bin/bash

die() {
	echo "$*" >&2
	exit 1
}
x() {
	echo " + $*" >&2
	"$@"
}

OUTPUT="$(podman container inspect -f '{{.State.Status}}' "${CONTAINER_ID}" 2>&1)"
if [[ ${OUTPUT} == *"no such container"* ]]; then
	exit 0
fi

if [[ ${OUTPUT} == "running" ]]; then
	echo "found running container."
	x podman stop --ignore "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
fi

if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
	echo "clearing dirty state."
	x podman rm --ignore --force "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
fi

if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
	echo "clearing dirty state (tree)."
	x podman rm --ignore --force --depend "--time=${PODMAN_TIMEOUT_TO_KILL}" "${CONTAINER_ID}"
fi

if podman container inspect "${CONTAINER_ID}" &>/dev/null; then
	die "still not able to remove container"
fi
