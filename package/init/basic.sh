#!/usr/bin/env bash

if [[ ${UID:+f} != f ]]; then
	UID=$(id -u)
	declare -irx UID
fi
function is_root() {
	return "${UID}"
}
function is_tty() {
	[[ -t ${1-2} ]]
}
function function_exists() {
	declare -fp "$1" &>/dev/null
}
function variable_is_array() {
	[[ $(declare -p "$1" 2>&1) == "declare -"a* ]]
}
function variable_is_map() {
	[[ $(declare -p "$1" 2>&1) == "declare -"A* ]]
}
function variable_bounded() {
	declare -p "$1" | grep -F " $1=" &>/dev/null
}
function variable_exists() {
	declare -p "$1" &>/dev/null
}
function trim() {
	local var="$*"
	# remove leading whitespace characters
	var="${var#"${var%%[![:space:]]*}"}"
	# remove trailing whitespace characters
	var="${var%"${var##*[![:space:]]}"}"
	printf '%s' "$var"
}

function is_ci() {
	[[ ${CI-} ]]
}

function _check_ci_env() {
	if is_ci; then
		info "[CI] 检测到 CI 环境"
		readonly CI
	else
		unset CI
		info "[CI] 无 CI 环境变量"
	fi
}

function guard_root_only() {
	if ! is_root; then
		die "此操作必须由 root 用户执行。"
	fi
}

function guard_no_root() {
	if is_root; then
		die "此操作不能由 root 用户执行。"
	fi
}

function export_array() {
	local R=''
	if [[ $1 == -r ]]; then
		R='r'
		shift
	fi

	local NAME=$1 I
	shift
	printf 'declare -%sa %s=(\n' "${R}" "${NAME}"
	if [[ $# -gt 0 ]]; then
		printf '\t%q\n' "$@"
	fi
	printf ')\n'
}

function hash_string() {
	local MOUT
	MOUT=$(echo "$1" | md5sum "${HASH_TMP}")
	echo "${MOUT}" | awk '{print $1}'
}

function export_function_body() {
	local FUNC_NAME="$1"
	# bash似乎不管怎么定义函数，declare -f 都会输出
	#     xxxx()
	#     {
	#     .....
	#     }
	# 所以删掉前2行和最后一行即可得到完整的函数体
	declare -f "$FUNC_NAME" | sed '1,2d;$d'
}
