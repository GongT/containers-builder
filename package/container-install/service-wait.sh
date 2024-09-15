function _service_executer_write() {
	local DATA='' TMPF
	TMPF=$(create_temp_file)

	DATA=$(
		call_script_emit
		__concat_wait_files
		echo main
	)

	construct_child_shell_script host - "${DATA}" >"${TMPF}"

	copy_file --mode 0744 "${TMPF}" "${SCRIPTS_DIR}/execute"
	echo "${SCRIPTS_DIR}/execute"
}

__concat_wait_files() {
	printf '\n\n'
	local FILE_PATH

	find "${COMMON_LIB_ROOT}/staff/service-wait" -type f -print0 | sort -z | while read -d '' -r FILE_PATH; do
		printf '\n## FILE: %s\n' "$(basename "${FILE_PATH}")"
		cat "${FILE_PATH}"
		printf '\n'
	done
}
get_debugger_script() {
	echo "${SCRIPTS_DIR}/debug-startup.sh"
}
_debugger_file_write() {
	local I EX_SRC TMPF

	TMPF=$(create_temp_file "debugger.script.file.sh")

	EX_SRC=$(
		echo "declare -r CONTAINER_ID='$(unit_get_scopename)'"
		echo "declare -r NAME='${_S_CURRENT_UNIT_NAME}'"
		echo "declare -r SERVICE_FILE='${_S_CURRENT_UNIT_FILE}'"
		call_script_emit
		__concat_wait_files
	)
	construct_child_shell_script host "${COMMON_LIB_ROOT}/staff/container-tools/debugger.sh" "${EX_SRC}" >"${TMPF}"

	copy_file --mode 0755 "${TMPF}" "$(get_debugger_script)"
}

function unit_start_notify() {
	info_warn "unit_start_notify has renamed to start_notify"
	start_notify "$@"
}
function start_notify() {
	local TYPE="$1" ARG="${2-}"
	_S_START_WAIT=
	case "${TYPE}" in
	socket)
		if [[ -n ${ARG} ]]; then
			die "touch method do not allow argument"
		fi
		_S_START_WAIT="socket"
		;;
	port)
		if [[ ${ARG} != */tcp && ${ARG} != */udp ]]; then
			die "start notify port must use xxx/tcp or xxx/udp"
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
		die "Unknown start notify method ${TYPE}, allow: socket, port, sleep, output, touch, pass, healthy. defaults to healthy if healthcheck exists, or sleep if not."
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
			die "unit wait for socket but not provide any."
		fi
	fi
	printf "declare START_WAIT_DEFINE=%q\n" "${_S_START_WAIT}"
}

register_script_emit __emit_start_helpers
