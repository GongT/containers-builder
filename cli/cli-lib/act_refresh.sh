#!/usr/bin/env bash

do_refresh() {
	local NEED_RESTART=() I
	local -A CONTAINER_SERVICE_MAP=()
	for I in $(do_ls); do
		CONTAINER_SERVICE_MAP["$(echo "$I" | sed -E 's/\.pod$//g; s/\.pod@/_/g')"]="$I"
	done

	while read -r CONTAINER IMAGE_ID IMAGE_NAME; do
		WANT_ID=$(podman inspect "$IMAGE_NAME" --type=image --format='{{.Id}}')
		if ! [[ $WANT_ID ]]; then
			echo "$IMAGE_NAME not exists" >&2
			continue
		fi
		if [[ $WANT_ID == "$IMAGE_ID" ]]; then
			UP_TO_DATE+=("${CONTAINER_SERVICE_MAP[$CONTAINER]}")
		else
			NEED_RESTART+=("${CONTAINER_SERVICE_MAP[$CONTAINER]}")
		fi
	done < <(podman inspect "${!CONTAINER_SERVICE_MAP[@]}" --type=container --format='{{.Name}} {{.Image}} {{.ImageName}}' || true)

	echo "${UP_TO_DATE[*]} is up to date" >&2
	echo "need update: ${NEED_RESTART[*]}"
	if [[ $* == *--run* ]]; then
		systemctl restart "${NEED_RESTART[@]}"
	fi
}
