#!/usr/bin/env bash

declare -a _REG_FILES=()

function get_written_files() {
	echo "${_REG_FILES[@]}"
}

function output_file() {
	local DATA
	DATA=$(cat)
	write_file "$@" "${DATA}"
}

function __fs_args() {
	while [[ $# -gt 0 ]]; do
		if [[ $1 == "--nodir" ]]; then
			MKDIR=0
		elif [[ $1 == "--mode" ]]; then
			shift
			MODE="$1"
		else
			ARGS+=("$1")
		fi
		shift
	done
}

function ensure_parent() {
	local MKDIR=$1 FILE=$2 DIR
	DIR=$(dirname "${FILE}")
	if [[ ${MKDIR} -eq 1 ]] && [[ ! -d ${DIR} ]]; then
		info_note "  * create directory: ${DIR}"
		mkdir -p "${DIR}"
	fi
}
function resolve() {
	local D="${PWD}" F
	for F; do
		if [[ ${F} == /* ]]; then
			D="${F}"
		else
			D=$(realpath -m "${D}/${F}")
		fi
	done
	echo "${D}"
}
function file_in_folder() {
	local FILE=$1 FOLDER=$2 REL
	REL=$(realpath --no-symlinks "--relative-base=${FOLDER}" "--relative-to=${FOLDER}" "${FILE}")
	[[ ${REL} != /* ]]
}
function is_project_file() {
	file_in_folder "$1" "${CURRENT_DIR}" || file_in_folder "$1" "${COMMON_LIB_ROOT}" || file_in_folder "$1" "${TMPDIR}"
}
function delete_file() {
	local -r MKDIR=$1 TARGET=$2
	local PARENT

	if [[ -e ${TARGET} ]]; then
		info_note "  * remove file: ${TARGET}"
		[[ -e ${TARGET} ]] && unlink "${TARGET}"
	fi

	if [[ ${MKDIR} -eq 1 ]]; then
		PARENT=$(dirname "${TARGET}")
		if [[ -d ${PARENT} ]]; then
			rmdir --ignore-fail-on-non-empty "${PARENT}"
		fi
	fi
}
function copy_file() {
	_arg_ensure_finish
	local ARGS MODE MKDIR=1
	__fs_args "$@"

	local FILE=${ARGS[0]} TARGET=${ARGS[1]}
	FILE=$(resolve "${CURRENT_DIR}" "${FILE}")
	if ! is_project_file "${FILE}"; then
		die "file outside project: ${FILE}"
	fi

	if [[ ${TARGET} != /* ]]; then
		die "copy_file target must be absolute path"
	fi

	if is_uninstalling; then
		delete_file "${MKDIR}" "${TARGET}"
		return
	fi

	_REG_FILES+=("${TARGET}")

	ensure_parent "${MKDIR}" "${TARGET}"
	info_note "  * copy file: ${TARGET}"
	cp -fpT "${FILE}" "${TARGET}"

	if [[ -n ${MODE-} ]]; then
		chmod "$(bit_mask "${MODE}")" "${TARGET}"
	else
		chmod a-w "${TARGET}"
	fi
}
function write_file() {
	_arg_ensure_finish
	local ARGS MODE MKDIR=1
	__fs_args "$@"
	local TARGET=${ARGS[0]} DATA=${ARGS[1]}
	TARGET=$(resolve "${SCRIPTS_DIR}" "${TARGET}")

	# info_warn "--> ${#TARGET} / ${#DATA} / ${MODE-unbound}"

	if is_uninstalling; then
		delete_file "${MKDIR}" "${TARGET}"
		return
	fi

	_REG_FILES+=("${TARGET}")

	ensure_parent "${MKDIR}" "${TARGET}"

	if [[ -e ${TARGET} ]] && [[ ${DATA} == "$(<"${TARGET}")" ]]; then
		info_note "  * write file: ${TARGET} - same"
	else
		if [[ -e ${TARGET} ]]; then
			rm -f "${TARGET}"
		fi
		echo "${DATA}" >"${TARGET}"
		info_note "  * write file: ${TARGET} - ok"
	fi
	if [[ -n ${MODE-} ]]; then
		chmod "$(bit_mask "${MODE}")" "${TARGET}"
	else
		chmod a-w "${TARGET}"
	fi
}
function bit_mask() {
	printf '0%o\n' $(($1 & (~0227)))
}
function find_command() {
	env -i "PATH=${PATH}" "${SHELL}" --noprofile --norc -c "command -v '$1'"
}
function ensure_symlink() {
	# uninstall
	local LINK_FILE=$1 TARGET=$2 CURR
	if [[ -L ${LINK_FILE} ]]; then
		CURR=$(readlink --canonicalize-missing --no-newline "${LINK_FILE}")
		if [[ ${CURR} != "${TARGET}" ]]; then
			unlink "${LINK_FILE}"
		else
			return
		fi
	elif [[ -f ${LINK_FILE} ]]; then
		info_warn "replacing normal file ${LINK_FILE} with a symlink"
		unlink "${LINK_FILE}"
	elif [[ -d ${LINK_FILE} ]]; then
		die "ensure_symlink: element exists and is a folder"
	fi

	mkdir -p "$(dirname "${LINK_FILE}")"
	ln -s "${TARGET}" "${LINK_FILE}"
}

function read_list_file() {
	local FILE=$1 VARNAME=$2 ARR
	mapfile -t ARR <"${FILE}"

	local ARR2=()
	for I in "${ARR[@]}"; do
		if [[ -z ${I} ]]; then
			continue
		fi

		if [[ ${I} == "#"* ]]; then
			continue
		fi

		ARR2+=("$(printf '%q' "${I}")")
	done

	eval "${VARNAME}=(${ARR2[*]})"
}
