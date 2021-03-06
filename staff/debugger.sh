#!/usr/bin/env bash

set -Eeuo pipefail

echo -ne "\ec"

if echo "$CONTAINER_ID" | grep -q '%i'; then
	template_id=$1
	shift

	if ! [[ "$template_id" ]]; then
		echo "for template (instantiated / ending with @) service, the first argument is the %i value."
		exit 1
	fi

	for I in "${!_S_PREP_FOLDER[@]}"; do
		V="${_S_PREP_FOLDER[$I]}"
		_S_PREP_FOLDER[$I]="${V//%i/${template_id}}"
	done

	function X() {
		local PODMAN_RUN=()
		for i; do
			PODMAN_RUN+=($(echo "$i" | sed "s/%i/${template_id}/g"))
		done
		XX "${PODMAN_RUN[@]}" "${PARENT_ARGS[@]}"
	}

else

	function X() {
		XX "${@}" "${PARENT_ARGS[@]}"
	}

fi

declare -a PARENT_ARGS=("$@")

function XX() {
	local ARGS=("$@")
	echo -ne "\e[2m"
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	echo
	echo -n "$1"
	for i in $(seq 1 $(($# - 1))); do
		echo -ne " \\\\\n  "
		echo -n "'${ARGS[$i]}'"
	done
	echo
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	echo -e "\e[0m"

	exec "${ARGS[@]}"
}

echo -ne "\e[2m"
printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""
systemctl cat "$SERVICE_FILE" --no-pager | sed -E "s/^/\x1B[2m/mg" || true
printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""

load_sdnotify

ensure_mounts "${_S_PREP_FOLDER[@]}"
podman volume prune -f &>/dev/null || true

make_arguments "${STARTUP_ARGS[@]}"
X podman run -it "${ARGS[@]}"
