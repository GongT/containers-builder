#!/usr/bin/env bash

declare -i INSIDE_GROUP=
SAVED_INDENT=()
export _CURRENT_INDENT=""
PRINT_STACK=yes

function control_ci() {
	local -r ACTION="$1"
	shift
	# info_log "[CI] Action=$ACTION, Args=$*" >&2
	case "${ACTION}" in
	set-env)
		local NAME=$1 VALUE=$2
		export "${NAME}=${VALUE}"
		if ! is_ci; then
			return
		fi

		{
			echo "${NAME}<<EOF"
			echo "${VALUE}"
			echo 'EOF'
		} >>"${GITHUB_ENV}"
		;;
	error | notice | warning)
		local TITLE=$1 MESSAGE=$2
		if is_ci; then
			echo "::${ACTION} title=${TITLE}::${MESSAGE}" >&2
		elif [[ ${ACTION} == 'error' ]]; then
			info_error "[CI EVENT: ${TITLE}]"
		elif [[ ${ACTION} == 'warning' ]]; then
			info_warn "[CI EVENT: ${TITLE}]"
		elif [[ ${ACTION} == 'notice' ]]; then
			info "[CI EVENT: ${TITLE}]"
		fi
		;;
	summary)
		if is_ci; then
			echo "$1" >>"${GITHUB_STEP_SUMMARY}"
		else
			printf "\e[2m"
			printf '=%.0s' $(seq 1 ${COLUMNS-80})
			printf '%s' "$1"
			printf '=%.0s' $(seq 1 ${COLUMNS-80})
			printf "\e[0m"
		fi
		;;
	group)
		INSIDE_GROUP=$((INSIDE_GROUP + 1))
		if [[ ${INSIDE_GROUP} -gt 5 ]]; then
			die "too many group level"
		fi
		if [[ ${INSIDE_GROUP} -eq 1 ]] && is_ci; then
			save_indent
			echo "::group::$*" >&2
		else
			info_bright "[Start Group] $*"
			indent
		fi
		;;
	groupEnd)
		if [[ ${INSIDE_GROUP} -eq 0 ]]; then
			info_error "mismatch group start / end"
			return
		fi
		INSIDE_GROUP=$((INSIDE_GROUP - 1))
		if [[ ${INSIDE_GROUP} -eq 0 ]] && is_ci; then
			restore_indent
			echo "::endgroup::" >&2
		else
			dedent
			info_note "[End Group]"
		fi
		;;
	*)
		die "[CI] not support action: ${ACTION}"
		;;
	esac
}

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
