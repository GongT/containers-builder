#!/usr/bin/env bash

declare -a ALL_CHANGED_FILES=()

function emit_file_changes() {
	ALL_CHANGED_FILES+=("$@")
}

function output_file() {
	local DATA
	DATA=$(cat)
	write_file "$@" "${DATA}"
}

function __fs_args() {
	let OPERATER=$1
	shift

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
	if [[ ${#ARGS[@]} -lt ${OPERATER} ]]; then
		die "无效的文件系统函数调用 (需要 ${OPERATER} 个参数)"
	fi
}

function ensure_parent() {
	local MKDIR=$1 FILE=$2 DIR
	DIR=$(dirname "${FILE}")
	if [[ ${MKDIR} -eq 1 ]] && [[ ! -d ${DIR} ]]; then
		info_note "  * 创建目录: ${DIR}"
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
		info_note "  * 删除文件: ${TARGET}"
		unlink "${TARGET}"
		emit_file_changes "${TARGET}"
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
	__fs_args 2 "$@"

	local FILE=${ARGS[0]} TARGET=${ARGS[1]}
	FILE=$(resolve "${CURRENT_DIR}" "${FILE}")
	if ! is_project_file "${FILE}"; then
		die "文件不在项目中: ${FILE}"
	fi

	if [[ ${TARGET} != /* ]]; then
		die "copy_file 目标必须是绝对路径"
	fi
	if [[ -d ${TARGET} ]]; then
		die "copy_file 目标已存在, 但它是一个目录"
	fi

	if is_uninstalling; then
		delete_file "${MKDIR}" "${TARGET}"
		return
	fi

	ensure_parent "${MKDIR}" "${TARGET}"

	if cmp --quiet "${FILE}" "${TARGET}"; then
		info_note "  * 复制文件: ${TARGET} - 相同"
	else
		cp -fpT "${FILE}" "${TARGET}"
		emit_file_changes "${TARGET}"
		info_note "  * 复制文件: ${TARGET} - 成功"
	fi

	if [[ -n ${MODE-} ]]; then
		chmod "$(bit_mask "${MODE}")" "${TARGET}"
	fi
}
function write_file() {
	_arg_ensure_finish
	local ARGS MODE MKDIR=1
	__fs_args 2 "$@"
	local TARGET=${ARGS[0]} DATA=${ARGS[1]}

	if [[ ${TARGET} == *$'\n'* ]]; then
		die "错误参数: 目标包含无效字符"
	fi

	TARGET=$(resolve "${SCRIPTS_DIR}" "${TARGET}")

	# info_warn "--> ${#TARGET} / ${#DATA} / ${MODE-unbound}"

	if is_uninstalling; then
		delete_file "${MKDIR}" "${TARGET}"
		return
	fi

	ensure_parent "${MKDIR}" "${TARGET}"

	if [[ -e ${TARGET} ]] && [[ ${DATA} == "$(<"${TARGET}")" ]]; then
		info_note "  * 写入文件: ${TARGET} - 相同"
	else
		if [[ -e ${TARGET} ]]; then
			rm -f "${TARGET}"
		fi
		echo "${DATA}" >"${TARGET}"
		emit_file_changes "${TARGET}"
		info_note "  * 写入文件: ${TARGET} - 成功"
	fi
	if [[ -n ${MODE-} ]]; then
		chmod "$(bit_mask "${MODE}")" "${TARGET}"
	fi
}
function bit_mask() {
	printf '0%o\n' $(($1 & (~0022)))
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
		info_warn "用符号链接替换普通文件 ${LINK_FILE}"
		unlink "${LINK_FILE}"
	elif [[ -d ${LINK_FILE} ]]; then
		die "ensure_symlink: 元素已存在且是文件夹"
	fi

	mkdir -p "$(dirname "${LINK_FILE}")"
	ln -s "${TARGET}" "${LINK_FILE}"
	emit_file_changes "${LINK_FILE}"
}

function read_list_file() {
	local -r FILE=$1
	local -r VARNAME=$2
	if ! variable_is_array "${VARNAME}"; then
		die "变量不是数组: ${VARNAME}"
	fi

	sed -E 's/#.*$//g; s/\s+$//g; /^$/d' "${FILE}" | mapfile -t "${VARNAME}"
}

function is_uninstalling() {
	[[ -n ${_ACTION_UNINSTALL} ]]
}
function is_installing() {
	[[ -z ${_ACTION_UNINSTALL} ]]
}
arg_flag _ACTION_UNINSTALL uninstall "uninstall (remove files)"
