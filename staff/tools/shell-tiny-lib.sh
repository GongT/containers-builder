function _exit_handle_in_container() {
	EXIT_CODE=$?
	set +Eeuo pipefail
	if [[ $EXIT_CODE -ne 0 ]]; then
		info_error "where is the error: ${WHO_AM_I-'unknown :('}"
		info_error "child script exit with error code ${EXIT_CODE}"
		callstack 1
	fi
}
trap _exit_handle_in_container EXIT

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

function control_ci() {
	return
}
