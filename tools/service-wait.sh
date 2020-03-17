#!/bin/bash

set -Eeuo pipefail

CONTAINER_ID=$1
WAIT_TIME=$2
I=$WAIT_TIME

echo "[wait-run] Wait container $CONTAINER_ID for $WAIT_TIME seconds."
while [[ "$I" -gt 0 ]]; do
	I=$(($I - 1))
	if ! podman inspect --type=container "$CONTAINER_ID" &>/dev/null ; then
		echo "[wait-run] Failed wait container $CONTAINER_ID to stable." >&2
		exit 1
	fi
	echo "[wait-run] $I." >&2
	sleep 1
done
echo "[wait-run] Container still running after $WAIT_TIME seconds."
