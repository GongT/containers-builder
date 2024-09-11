declare -r SHELL_SCRIPT_PREFIX=$'#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose
'

function _service_executer_write() {
	local DATA="$SHELL_SCRIPT_PREFIX"

	DATA+=$(call_script_emit)
	DATA+=$(__concat_wait_files)

	write_file --mode 0755 "${SCRIPTS_DIR}/execute" "${DATA}"
	echo "${SCRIPTS_DIR}/execute"
}

__concat_wait_files() {
	local FILE_PATH
	find "${COMMON_LIB_ROOT}/staff/service-wait" -type f -print0 | sort -z | while read -d '' -r FILE_PATH; do
		echo
		echo "## $(basename "${FILE_PATH}")"
		tail -n +4 "${FILE_PATH}"
		echo
	done
}
get_debugger_script() {
	echo "${SCRIPTS_DIR}/debug-startup.sh"
}
_debugger_file_write() {
	local I FILE_DATA
	local -a STARTUP_ARGS=()

	_create_startup_arguments
	FILE_DATA=$(
		echo "$SHELL_SCRIPT_PREFIX"
		echo "declare -r CONTAINER_ID='$(_unit_get_scopename)'"
		echo "declare -r NAME='${_S_CURRENT_UNIT_NAME}'"
		echo "declare -r SERVICE_FILE='${_S_CURRENT_UNIT_FILE}'"
		call_script_emit
		__concat_wait_files

		echo "STARTUP_ARGC=${#_S_COMMAND_LINE[@]}"
		echo "declare -a STARTUP_ARGS=("
		printf '\t%q\n' "${STARTUP_ARGS[@]}"
		echo ")"

		cat "${COMMON_LIB_ROOT}/staff/container-tools/debugger.sh"
	) || die "failed construct execute file"
	write_file --mode 0755 "$(get_debugger_script)" "${FILE_DATA}"
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
		_S_START_WAIT="sockets"
		;;
	port)
		if [[ ${ARG} != tcp:* && ${ARG} != udp:* ]]; then
			die "start notify port must use tcp:xxx or udp:xxx"
		fi
		_S_START_WAIT="net:${ARG}"
		;;
	sleep)
		_S_START_WAIT="sleep:${ARG}"
		;;
	output)
		_S_START_WAIT="output:${ARG}"
		;;
	touch)
		_S_START_WAIT="file"
		;;
	pass)
		_S_START_WAIT="pass"
		;;
	*)
		die "Unknown start notify method ${TYPE}, allow: socket, port, sleep, output, touch, pass."
		;;
	esac
}

function __provide_sockets_for_wait() {
	_S_WAIT_SOCKETS+=("$@")
}

function __reset_start_notify() {
	_S_START_WAIT=sleep:10
	declare -a _S_WAIT_SOCKETS=()
}

register_unit_reset __reset_start_notify

function __emit_start_helpers() {
	if [[ $_S_START_WAIT == sockets ]]; then
		if [[ ${#_S_WAIT_SOCKETS[@]} -eq 0 ]]; then
			die "unit wait for socket but not provide any."
		fi
		_S_START_WAIT+=":${_S_WAIT_SOCKETS[0]}"
	fi
	printf "declare -r START_WAIT_DEFINE=%q" "${_S_START_WAIT}"
}

register_script_emit __emit_start_helpers
