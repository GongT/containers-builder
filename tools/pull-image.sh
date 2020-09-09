#!/usr/bin/env bash

set -Eeuo pipefail

function sdnotify() {
	if [[ "${NOTIFY_SOCKET+found}" = found ]]; then
		systemd-notify "$@"
	fi
}

declare -rx IMAGE_TO_PULL=$1
if [[ "$2" != "always" ]]; then
	if podman inspect --type=image "$IMAGE_TO_PULL" &> /dev/null; then
		echo "Image already exists: $IMAGE_TO_PULL"
		return
	fi
fi

sdnotify "--status=pull image"

unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

echo "Pull image $IMAGE_TO_PULL from registry..."

sdnotify "--status=EXTEND_TIMEOUT_USEC=$((60 * 1000 * 1000))"

podman pull "$IMAGE_TO_PULL"

sdnotify "--status=EXTEND_TIMEOUT_USEC=$((30 * 1000 * 1000))"
