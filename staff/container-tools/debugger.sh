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

	set +e
	/usr/bin/podman "${ARGS[@]}"
	RET=$?

	echo ""
	echo ""
	local C=""
	if [[ ${RET} -ne 0 ]]; then
		C="\e[31m"
	fi
	echo -e "${C}podman 退出码: ${RET}\e[0m"
}

declare -xr CONTAINER_ID="debug_container_$(template_id='i' filter_systemd_template "${UNIT_NAME}")_${RANDOM}"

printf "\e[2m"
printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""
printf '容器Id（名称）: %s\n' "${CONTAINER_ID}"
printf '服务单元文件: %s\n' "$SERVICE_FILE"
printf 'Podman 参数: %s\n' "${ENGINE_PARAMS[*]}"
printf '镜像名称: %s\n' "${PODMAN_IMAGE_NAME}"
printf '默认命令行: %s\n' "${COMMAND_LINE[*]}"
printf '输入命令行: %s\n' "$*"
printf '环境变量/ENTRYPOINT: %s\n' "${ENTRYPOINT-image default}"

printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""

# 根据以下几个输入
#     ENGINE_PARAMS - podman run的参数，到image为止
#     PODMAN_IMAGE_NAME
#     COMMAND_LINE - 默认要执行的命令
#     $@ - 如果有，就替代默认命令
# 模拟出execute的输入参数
#     COMMAND_LINE

if [[ "${ENTRYPOINT-}" ]]; then
	RESULT+=("--entrypoint=$ENTRYPOINT")
fi

COPY=()
for A in "${ENGINE_PARAMS[@]}"; do
	COPY+=("$(filter_systemd_template "$A")")
done
ENGINE_PARAMS=("${COPY[@]}")
ENGINE_PARAMS+=("--name=${CONTAINER_ID}")
ENGINE_PARAMS+=("--env=IN_DEBUG_MODE=yes")

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

push_engine_param "--log-level=info" "--log-driver=k8s-file"
push_engine_param "--env=CONTAINER_ID=${CONTAINER_ID}"

ensure_mounts

make_arguments

X=("${PODMAN_EXEC_ARGS[@]}")
PODMAN_EXEC_ARGS=()
for I in "${X[@]}"; do
	if [[ ${I} == "--cgroup-parent="* ]]; then
		continue
	fi
	if [[ ${REAL_NETWORK-} != 1 ]] && [[ ${I} == "--mac-address="* || ${I} == "--pod="* ]]; then
		info "从podman参数移除 '${I}', 设置 REAL_NETWORK=1 可防止此操作."
		continue
	fi
	PODMAN_EXEC_ARGS+=("${I}")
done

xpodman run --interactive --tty "${PODMAN_EXEC_ARGS[@]}"
