function _exit_handle_in_script() {
	EXIT_CODE=$?
	set +Eeuo pipefail
	trap - ERR

	info_note "[exit] call handler: code=${EXIT_CODE}, pid=$$"

	call_exit_handlers

	if [[ $EXIT_CODE -ne 0 ]]; then
		info_error "[exit] where is the error: ${WHO_AM_I-'unknown :('}"
		info_error "[exit] child script exit with error code ${EXIT_CODE}"
		callstack 1
	fi
	exit $EXIT_CODE
}
trap _exit_handle_in_script EXIT

function create_temp_dir() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	mktemp "--tmpdir=${TMPDIR}" --directory "${FILE_BASE}.XXXXX.${FILE_EXT}"
}

function create_temp_file() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	mktemp "--tmpdir" "${FILE_BASE}.XXXXX.${FILE_EXT}"
}
