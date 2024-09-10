#!/usr/bin/env bash

if [[ ${UID:+f} != f ]]; then
	UID=$(id -u)
	declare -irx UID
fi
function is_root() {
	return "${UID}"
}
function is_set() {
	declare -p "$1" &>/dev/null
}
function is_tty() {
	[[ -t ${1:-2} ]]
}
function function_exists() {
	declare -F "${PREFIX_FN}" >/dev/null
}

function is_ci() {
	[[ ${CI+found} == "found" ]] && [[ -n ${CI} ]]
}

function _check_ci_env() {
	if is_ci; then
		info_note "CI=${CI}"
		export CI
	else
		unset CI
		info_note "CI=*not set*"
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
