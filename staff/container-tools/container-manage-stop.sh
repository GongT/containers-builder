#!/usr/bin/bash

KILL_TIMEOUT="$1"
SCOPE_ID="$2"

die() {
	echo "$*" >&2
	exit 1
}
x() {
	echo " + $*" >&2
	"$@" >&2
}

OUTPUT="$(podman inspect --type container -f '{{.State.Status}}' "${SCOPE_ID}" 2>&1)"
if [[ "${OUTPUT}" = *"no such container"* ]]; then
	exit 0
fi

if [[ "${OUTPUT}" = "running" ]]; then
	x podman stop --time "${KILL_TIMEOUT}" "${SCOPE_ID}" || die "Failed!"
else
	x podman rm -f "${SCOPE_ID}" || die "Failed!"
fi

# function clean_images() {
# 	podman images | grep -E '<none>' | awk '{print $3}' | xargs --no-run-if-empty --verbose --no-run-if-empty podman rmi >&2
# }

# clean_images
