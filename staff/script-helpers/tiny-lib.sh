#!/usr/bin/bash

function _exit_handle_in_script() {
	EXIT_CODE=$?
	set +Eeuo pipefail
	trap - ERR

	info_note "[exit] 退出回调被调用: 上个命令返回=${_EXIT_CODE}, ERRNO=${ERRNO}, EXIT_CODE=${EXIT_CODE-missing}, 当前进程ID=$$"

	call_exit_handlers

	if [[ $EXIT_CODE -ne 0 ]]; then
		info_error "[exit] 容器内脚本发生错误"
		info_log "         错误发生在: ${WHO_AM_I-未知😢}"
		info_log "         子进程退出码: ${EXIT_CODE}"
		callstack 1
	fi
	exit $EXIT_CODE
}
trap _exit_handle_in_script EXIT

if [[ -z ${TMPDIR-} ]]; then
	declare -xr TMPDIR='/tmp'
fi

function create_temp_dir() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	mktemp "--tmpdir=${TMPDIR}" --directory "${FILE_BASE}.XXXXX.${FILE_EXT}"
}

function create_temp_file() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	mktemp "--tmpdir=${TMPDIR}" "${FILE_BASE}.XXXXX.${FILE_EXT}"
}
