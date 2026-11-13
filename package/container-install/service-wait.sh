function _service_executer_write() {
	local DATA='' TMPF
	TMPF=$(create_temp_file)

	{
		echo '#!/usr/bin/bash'
		echo 'source "__replace_me__/include.sh"'
		__concat_wait_files
		echo use_normal
		echo execute_service_waiter_main
	} >"${TMPF}"

	WHO_AM_I='service-waiter' \
		install_script "${TMPF}" "${PROJECT_NAME}.pod"
}

__concat_wait_files() {
	printf '\n\n'
	local FILE_PATH

	find "${COMMON_LIB_ROOT}/staff/service-wait" -type f -print0 | sort -z | while read -d '' -r FILE_PATH; do
		cat_source_file "${FILE_PATH}"
	done
}

_debugger_remove_domain() {
	if [[ ${PODMAN_IMAGE_NAME} == "${PODMAN_MY_REGISTRY}"/* ]]; then
		info_note "从PODMAN_IMAGE_NAME中删除前缀 ${PODMAN_MY_REGISTRY}/"
		PODMAN_IMAGE_NAME="${PODMAN_IMAGE_NAME#"${PODMAN_MY_REGISTRY}"/}"
	fi
}

_debugger_file_write() {
	local I EX_SRC TMPF OUTPUT

	TMPF=$(create_temp_file "debugger.script.file.sh")

	local SRC="${COMMON_LIB_ROOT}/staff/container-tools/debugger.sh"
	(
		echo '#!/usr/bin/bash'
		echo 'source "__replace_me__/include.sh"'

		export_function_body _debugger_remove_domain
		__concat_wait_files
		cat_source_file "${SRC}"
	) >"${TMPF}"

	WHO_AM_I='service-waiter (debug)' \
		install_script "${TMPF}" "debug-start.sh"
}

function start_notify() {
	local TYPE="$1" ARG="${2-}"
	_S_START_WAIT=
	case "${TYPE}" in
	socket)
		if [[ -n ${ARG} ]]; then
			die "socket方法不支持参数"
		fi
		_S_START_WAIT="socket"
		;;
	port)
		if [[ ${ARG} != */tcp && ${ARG} != */udp ]]; then
			die "port方法必须使用 xxx/tcp 或 xxx/udp"
		fi
		_S_START_WAIT="port:${ARG}"
		;;
	sleep)
		_S_START_WAIT="sleep:${ARG}"
		;;
	output)
		_S_START_WAIT="output:${ARG}"
		;;
	touch)
		_S_START_WAIT="touch:${ARG}"
		;;
	pass)
		_S_START_WAIT="pass"
		;;
	healthy)
		_S_START_WAIT="healthy"
		;;
	auto)
		_S_START_WAIT="auto"
		;;
	*)
		die "未知的 start notify 方法 ${TYPE}，允许: socket, port, sleep, output, touch, pass, healthy. 如果存在健康检查，默认为 healthy，否则为 sleep"
		;;
	esac
}
function __reset_start_notify() {
	declare -g _S_START_WAIT=
}

register_unit_reset __reset_start_notify

function __emit_start_helpers() {
	if [[ -z $_S_START_WAIT ]]; then
		_S_START_WAIT="auto"
	elif [[ $_S_START_WAIT == socket ]]; then
		if [[ ${#_S_PROVIDE_SOCKETS[@]} -eq 0 ]]; then
			die "单元使用 socket 方法判定容器启动，但未提供任何 socket"
		fi
	fi
	printf "declare START_WAIT_DEFINE=%q\n" "${_S_START_WAIT}"
}

register_script_emit __emit_start_helpers
