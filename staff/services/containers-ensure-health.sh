#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "./common_service_library.sh"

mapfile -t IDS < <(podman ps --format '{{.ID}}')

for ID in "${IDS[@]}"; do
	sdnotify "inspect ${ID}..."
	STATUS=$(podman inspect "${ID}" --type=container --format='{{.State.Healthcheck.Status}}')
	if [[ ${STATUS} == healthy ]]; then
		debug "[**] it is healthy"
	elif [[ ${STATUS} == unhealthy ]]; then
		sdnotify "[!!] kill container ${ID}"
		if podman stop "${ID}" -t 30; then
			debug "    success!"
		else
			debug "    not quit in 30s!"
		fi
	else
		debug "[**] health check is disabled. ${STATUS:-}"
	fi
done

startup_done
