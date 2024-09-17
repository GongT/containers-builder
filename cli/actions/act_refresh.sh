#!/usr/bin/env bash

do_refresh() {
	local NEED_RESTART=() I
	local -A CONTAINER_SERVICE_MAP=()
	for I in $(do_ls); do
		CONTAINER_SERVICE_MAP["$(echo "$I" | sed -E 's/\.pod$//g; s/\.pod@/_/g')"]="$I"
	done

	while read -r CONTAINER IMAGE_ID IMAGE_NAME; do
		WANT_ID=$(podman image inspect "$IMAGE_NAME" --format='{{.Id}}')
		if [[ -z $WANT_ID ]]; then
			echo "$IMAGE_NAME not exists" >&2
			continue
		fi
		if [[ $WANT_ID == "$IMAGE_ID" ]]; then
			UP_TO_DATE+=("${CONTAINER_SERVICE_MAP[$CONTAINER]}")
		else
			NEED_RESTART+=("${CONTAINER_SERVICE_MAP[$CONTAINER]}")
		fi
	done < <(podman container inspect "${!CONTAINER_SERVICE_MAP[@]}" --format='{{.Name}} {{.Image}} {{.ImageName}}' || true)

	if [[ -t 0 ]] && [[ -t 1 ]]; then
		echo -e "\e[38;5;10mUp to date:\e[0m" >&2
		if [[ ${#UP_TO_DATE[@]} -gt 0 ]]; then
			for I in "${UP_TO_DATE[@]}"; do
				echo -e "  * $I" >&2
			done
		else
			echo "  nothing"
		fi
		echo -e "\e[38;5;11mNeed restart:\e[0m" >&2
		if [[ ${#NEED_RESTART[@]} -gt 0 ]]; then
			for I in "${NEED_RESTART[@]}"; do
				echo -e "  * $I" >&2
			done
		else
			echo "  nothing"
		fi
	fi
	if [[ $* == *--run* ]]; then
		echo "restarting ${NEED_RESTART[*]} ..."
		systemctl restart "${NEED_RESTART[@]}"
	else
		echo "use $0 $* --run to execute restart command." >&2
	fi
}
