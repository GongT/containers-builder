#!/usr/bin/env bash

SAVED_INDENT=()
export _CURRENT_INDENT=""
PRINT_STACK=yes

function info() {
	echo -e "${_CURRENT_INDENT}\e[38;5;14m$*\e[0m" >&2
}
function info_note() {
	echo -e "${_CURRENT_INDENT}\e[2m$*\e[0m" >&2
}
function info_log() {
	echo "${_CURRENT_INDENT}$*" >&2
}
function info_warn() {
	echo -e "${_CURRENT_INDENT}\e[38;5;11m$*\e[0m" >&2
}
function info_success() {
	echo -e "${_CURRENT_INDENT}\e[38;5;10m$*\e[0m" >&2
}
function info_error() {
	echo -e "${_CURRENT_INDENT}\e[38;5;9m$*\e[0m" >&2
}
function info_bright() {
	echo -e "${_CURRENT_INDENT}\e[1m$*\e[0m" >&2
}
function info_stream() {
	# deprecated
	sed -u "s/^/${_CURRENT_INDENT}/" >&2
}
function indent_multiline() {
	echo "$*" | sed -u "s/^/${_CURRENT_INDENT}/" >&2
}
function indent_stream() {
	if [[ -z ${_CURRENT_INDENT} ]]; then
		"$@"
	else
		local _CIDD="${_CURRENT_INDENT}"
		save_indent
		{
			"$@"
		} > >(sed -u "s/^/${_CIDD}/") 2> >(sed -u "s/^/${_CIDD}/" >&2)
		restore_indent
	fi
}

function indent() {
	export _CURRENT_INDENT+="    "
}
function dedent() {
	if [[ ${_CURRENT_INDENT: -4} != '    ' ]]; then
		return
	fi
	export _CURRENT_INDENT=${_CURRENT_INDENT:0:-4}
}
function save_indent() {
	SAVED_INDENT=("${_CURRENT_INDENT}" "${SAVED_INDENT[@]}")
	_CURRENT_INDENT=
}
function restore_indent() {
	_CURRENT_INDENT=${SAVED_INDENT[0]}
	SAVED_INDENT=("${SAVED_INDENT[@]:1}")
}

function x() {
	info_note " + ${*}"
	"$@"
}

_LINE_LABEL=""
function branch_split() {
	if [[ -n ${_LINE_LABEL} ]]; then
		die "tty_split can not call twice"
	fi
	local LABEL=$1
	if [[ -z ${LABEL} ]]; then
		die "empty label"
	fi

	if is_tty 2; then
		echo -ne "\e[2m  * ${LABEL} \e[0m" >&2
	fi
}

function branch_join() {
	if [[ -z ${_LINE_LABEL} ]]; then
		die "branch_join without branch_split"
	fi
	local RESULT=$1
	if is_tty 2; then
		echo -e "\e[2m-> ${RESULT}\e[0m" >&2
	else
		echo -e "\e[2m${_LINE_LABEL} -> ${RESULT}\e[0m" >&2
	fi
}
