#!/usr/bin/env bash

printf "\ec"

function xpodman() {
	local ARGS=("$@")
	printf "\e[2m"
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	echo
	echo -n "podman ${ARGS[0]}"
	printf ' \\\n\t %q' "${ARGS[@]:1}"
	echo
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	printf "\e[0m\n"

	exec podman "${ARGS[@]}"
}

function filter_systemd_template() {
	echo "$1" | sed "s/%i/${template_id}/g"
}

printf "\e[2m"
printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""
printf 'Service File: %s\n' "$SERVICE_FILE"
printf 'Podman Params: %s\n' "${ENGINE_PARAMS[*]}"
printf 'Image Name: %s\n' "${PODMAN_IMAGE_NAME}"
printf 'Default Commandline: %s\n' "${COMMAND_LINE[*]}"
printf 'Input Commandline: %s\n' "$*"
printf 'env:ENTRYPOINT: %s\n' "${ENTRYPOINT-image default}"

printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""

# 根据以下几个输入
#     ENGINE_PARAMS - podman run的参数，到image为止
#     PODMAN_IMAGE_NAME
#     COMMAND_LINE - 默认要执行的命令
#     $@ - 如果有，就替代默认命令
# 模拟出execute的输入参数
#     COMMAND_LINE

if echo "$CONTAINER_ID" | grep -q '%i'; then
	if [[ -z ${template_id-} ]]; then
		die "for template (instantiated / ending with @) service, must have environment variable: template_id"
	fi
else
	declare -g template_id='!'
fi

if [[ "${ENTRYPOINT-}" ]]; then
	echo "force using entrypoint: $ENTRYPOINT"
	RESULT+=("--entrypoint=$ENTRYPOINT")
fi

COPY=()
for A in "${ENGINE_PARAMS[@]}"; do
	if [[ $A == "--mac-address="* ]]; then
		continue
	fi
	COPY+=("$(filter_systemd_template "$A")")
done
ENGINE_PARAMS=("${COPY[@]}")

if [[ $# -gt 0 ]]; then
	COMMAND_LINE=("$@")
else
	COPY=()
	for I in "${COMMAND_LINE[@]}"; do
		COPY+=("$(filter_systemd_template "$I")")
	done
	COMMAND_LINE=("${COPY[@]}")
fi

unset I A RESULT

detect_image_using_systemd

load_sdnotify

ensure_mounts

make_arguments

xpodman run -it "${PODMAN_EXEC_ARGS[@]}"
