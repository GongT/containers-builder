#!/usr/bin/env bash

set -Eeuo pipefail

echo -ne "\ec"

function x() {
	local ARGS=("$@")
	printf "\e[2m"
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	echo
	echo -n "${ARGS[0]}"
	printf ' \\\n\t %q' "${ARGS[@]:1}"
	echo
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	printf "\e[0m\n"

	exec "${ARGS[@]}"
}

if [[ ${#DEFAULT_COMMANDLINE[@]} -gt 0 ]]; then
	E=$((${#STARTUP_ARGS[@]} - ${#DEFAULT_COMMANDLINE[@]}))
	STARTUP_ARGS=("${STARTUP_ARGS[@]:0:E}")
	unset E
fi

STARTUP_ARGS_COPY=("${STARTUP_ARGS[@]}")
STARTUP_ARGS=()
for A in "${STARTUP_ARGS_COPY[@]}"; do
	if [[ $A == "--mac-address="* ]]; then
		continue
	fi
	STARTUP_ARGS+=("$A")

done
unset STARTUP_ARGS_COPY

if echo "$CONTAINER_ID" | grep -q '%i'; then
	template_id=${INPUT_ARGUMENTS[0]}
	INPUT_ARGUMENTS=("${INPUT_ARGUMENTS[@]:1}")

	if [[ -z $template_id ]]; then
		echo "for template (instantiated / ending with @) service, the first argument is the %i value."
		exit 1
	fi

	function xpodman() {
		local ARG_FILTER=()
		for i; do
			ARG_FILTER+=("$(echo "$i" | sed "s/%i/${template_id}/g")")
		done
		x podman "${ARG_FILTER[@]}"
	}

else

	function xpodman() {
		x podman "$@"
	}

fi

printf "\e[2m"
printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""
printf 'Service File: %s\n' "$SERVICE_FILE"
printf 'Default Commandline: %s\n' "${DEFAULT_COMMANDLINE[*]}"
printf 'Options: %s\n' "${STARTUP_ARGS[*]}"
printf 'Current Commandline: %s\n' "${INPUT_ARGUMENTS[*]}"
printf 'env:ENTRYPOINT: %s\n' "${ENTRYPOINT-image default}"

ARGS=("${ARGS[@]}" "${STARTUP_ARGS[@]}")

printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""

detect_image_using_systemd

load_sdnotify

ensure_mounts

make_arguments

if [[ "${ENTRYPOINT-}" ]]; then
	echo "force using entrypoint: $ENTRYPOINT"
	ARGS=("--entrypoint=$ENTRYPOINT" "${ARGS[@]}")
fi

xpodman run -it "${ARGS[@]}"
