#!/usr/bin/env bash

function die() {
	echo -e "Error: $*\n\e[2m$(callstack)\e[0m" >&2
	control_ci "::error ::$*"
	exit 1
}

function control_ci() {
	if is_ci; then
		echo "$*" >&2
		echo "[CI]! $*" >&2
	fi
}

function callstack() {
	local -i SKIP=${1-1}
	local -i i
	for i in $(seq $SKIP $((${#FUNCNAME[@]} - 1))); do
		if [[ "${BASH_SOURCE[$((i + 1))]+found}" = "found" ]]; then
			echo "  $i: ${BASH_SOURCE[$((i + 1))]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}()"
		else
			echo "  $i: ${FUNCNAME[$i]}()"
		fi
	done
}

function _exit_handle() {
	set +xe
	RET=$?
	echo -ne "\e[0m"
	if [[ "$RET" -ne 0 ]]; then
		control_ci "::error ::bash exit with error code $RET"
		callstack 1
	fi
	exit $RET
}
trap _exit_handle EXIT

function info() {
	echo -e "$_CURRENT_INDENT\e[38;5;14m$*\e[0m" >&2
}
function info_note() {
	echo -e "$_CURRENT_INDENT\e[2m$*\e[0m" >&2
}
function info_log() {
	echo "$_CURRENT_INDENT$*" >&2
}
function info_warn() {
	echo -e "$_CURRENT_INDENT\e[38;5;11m$*\e[0m" >&2
}

export _CURRENT_INDENT=""
function indent() {
	export _CURRENT_INDENT+="    "
}
function dedent() {
	export _CURRENT_INDENT="${_CURRENT_INDENT:4}"
}
