#!/usr/bin/env bash

# shellcheck source=../../package/include.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/service-library.sh"

load_sdnotify

mapfile -t IDS < <(podman ps --format '{{.ID}}')

for ID in "${IDS[@]}"; do
	sdnotify "--status=inspect ${ID}..."
	STATUS=$(podman container inspect "${ID}" | filtered_jq '.[0].State.Health.Status' || true)
	if [[ ${STATUS} == healthy ]]; then
		info_log "[**] it is healthy"
	elif [[ ${STATUS} == unhealthy ]]; then
		sdnotify "--status=[!!] kill container ${ID}"
		if podman stop "${ID}" -t 30; then
			info_log "    success!"
		else
			info_log "    not quit in 30s!"
		fi
	elif [[ -n ${STATUS} ]]; then
		info_log "    state: ${STATUS}"
	else
		info_log "[**] health check is disabled. ${STATUS-}"
	fi
done

sdnotify --ready
