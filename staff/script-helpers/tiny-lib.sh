#!/bin/bash

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

function ensure_user() {
	local U_ID=$1 U_NAME=$2 G_ID=$3
	if cat /etc/passwd | grep -- "$U_NAME" | grep -q -- ":$U_ID:$G_ID:"; then
		echo "Group $U_NAME exists with id $U_ID"
	else
		useradd --gid "$G_ID" --no-create-home --no-user-group --uid "$U_ID" "$U_NAME"
		echo "Created $U_NAME."
	fi
}

function ensure_group() {
	local G_ID=$1 G_NAME=$2
	if cat /etc/group | grep -- "$G_NAME" | grep -q -- ":$G_ID:"; then
		echo "Group $G_NAME exists with id $G_ID"
	else
		groupadd -g "$G_ID" "$G_NAME"
		echo "Created $G_NAME."
	fi
}

function create_user() {
	local NAME=$1 ID=$2
	ensure_group "${ID}" "${NAME}"
	ensure_user "${ID}" "${NAME}" "${ID}"
}
