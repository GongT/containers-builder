#!/usr/bin/env bash

if [[ ${UID:+f} != f ]]; then
	UID=$(id -u)
	declare -irx UID
fi
function is_root() {
	return "${UID}"
}
function is_tty() {
	[[ -t ${1:-2} ]]
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
		info "[CI] dectected CI environment"
		readonly CI
	else
		unset CI
		info "[CI] no CI environment"
	fi
}

function guard_root_only() {
	if ! is_root; then
		die "This action must run by root."
	fi
}

function guard_no_root() {
	if is_root; then
		die "This action can not run by root."
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
