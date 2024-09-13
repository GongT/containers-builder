#!/usr/bin/env bash

INSIDE_GROUP=
SAVED_INDENT=()
export _CURRENT_INDENT=""
PRINT_STACK=yes

function die() {
	local LASTERR=$?
	control_ci groupEnd
	echo -e "\n\e[38;5;9;1mFatalError: $*\e[0m" >&2
	if [[ ${PRINT_STACK-no} == yes ]]; then
		callstack 2
	fi
	control_ci error "$*"
	if [[ $LASTERR -gt 0 ]]; then
		exit $LASTERR
	elif [[ ${ERRNO-} -gt 0 ]]; then
		exit $ERRNO
	else
		exit 1
	fi
}

function print_failure() {
	info_error "$@"
	return 66
}

function export_script_variable() {
	declare -p "$@" 2>/dev/null || true
}
function export_script_function() {
	declare -fp "$@" 2>/dev/null || true
}

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
		elif [[ -n ${GITHUB_ENV-} ]]; then
			{
				echo "${NAME}<<EOF"
				echo "${VALUE}"
				echo 'EOF'
			} >>"${GITHUB_ENV}"
		elif [[ -n ${GITLAB_ENV-} ]]; then
			{
				echo "${NAME}=\$(cat <<EOF"
				echo "${VALUE}"
				echo 'EOF'
				echo ')'
			} >>"${GITLAB_ENV}"
		else
			die "[CI] does not support current ci."
		fi
		;;
	error)
		if [[ -n ${GITHUB_ACTIONS-} ]]; then
			echo "::error ::$*" >&2
		fi
		;;
	group)
		if [[ -n ${INSIDE_GROUP} ]]; then
			die "not allow nested output group"
		fi
		INSIDE_GROUP=yes
		if [[ -n ${GITHUB_ACTIONS-} ]]; then
			save_indent
			echo "::group::$*" >&2
		else
			info_bright "[Start Group] $*"
			indent
		fi
		;;
	groupEnd)
		if [[ -z ${INSIDE_GROUP} ]]; then
			return # must allow, die() rely on this
		fi
		INSIDE_GROUP=
		if [[ -n ${GITHUB_ACTIONS-} ]]; then
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

function SHELL_SCRIPT_PREFIX() {
	echo '#!/usr/bin/env bash'
	declare -fp use_strict use_normal
	echo 'use_normal'
}

function SHELL_COMMON_LIBS() {
	echo '
declare _CURRENT_INDENT=""
# function try_resolve_file() {
# 	echo "[in container] $*"
# }
'
	declare -pf callstack filtered_jq json_array json_array_get_back \
		die indent dedent x \
		info info_note info_log info_warn info_success info_error info_bright info_stream \
		is_set is_tty function_exists \
		global_error_trap set_error_trap is_bash_function try_call_function

	declare -fp uptime_sec timespan_seconds seconds_timespan systemd_service_property
	declare -p microsecond_unit

	declare -p JQ_ARGS
	if [[ -n ${CI-} ]]; then
		declare -p CI
	else
		echo "unset CI"
	fi
	echo 'set_error_trap'
	cat "${COMMON_LIB_ROOT}/staff/tools/shell-tiny-lib.sh"
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
	export _CURRENT_INDENT="${_CURRENT_INDENT:4}"
}
function save_indent() {
	SAVED_INDENT=("${_CURRENT_INDENT}" "${SAVED_INDENT[@]}")
	_CURRENT_INDENT=
}
function restore_indent() {
	_CURRENT_INDENT=${SAVED_INDENT[0]}
	SAVED_INDENT=("${SAVED_INDENT[@]:1}")
}

declare -r JQ_ARGS=(--exit-status --compact-output --monochrome-output --raw-output)
function filtered_jq() {
	local INPUT
	INPUT=$(jq "${JQ_ARGS[@]}" "$@")
	if [[ ${INPUT} == "null" ]]; then
		die "failed query $1"
	fi
	echo "${INPUT}"
}

function json_array() {
	if [[ $# -eq 0 ]]; then
		echo '[]'
		return
	fi
	jq --ascii-output --null-input --compact-output --slurp '$ARGS.positional' --args -- "$@"
}

function json_array_get_back() {
	local -i SIZE i
	local VARNAME="$1" JSON="$2"
	local -a ARR=()
	SIZE=$(echo "${JSON}" | jq --compact-output '.|length')
	for ((i = 0; i < SIZE; i++)); do
		ARR+=("$(echo "${JSON}" | jq --compact-output --raw-output ".[${i}]")")
	done
	eval "${VARNAME}=(\"\${ARR[@]}\")"
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

declare -a __CURPOS__
function get_cursor_position() {
	if ! is_tty || is_ci; then
		return
	fi
	printf "\e[6n"
	local RESP
	read -t 1 -r -s -d 'R' RESP
	RESP="${RESP:2}"
	__CURPOS__=("${RESP%;*}" "${RESP#*;}")

	# printf '\e[38;5;9m|\e[0m' >&2
}
function restore_cursor_position() {
	if ! is_tty || is_ci || [[ -z ${__CURPOS__[0]} ]]; then
		return
	fi

	printf "\e[%d;%dH\e[J" "${__CURPOS__[@]}"
	__CURPOS__=()
}

function alternative_buffer_execute() {
	local TITLE="$1" RET
	shift
	if ! is_ci && is_tty && [[ ${ALTERNATIVE_BUFFER_ENABLED} == no ]]; then
		info_warn "$TITLE"
		printf '\e[?1049h'
		ALTERNATIVE_BUFFER_ENABLED=yes
		local TMP_OUT
		TMP_OUT=$(create_temp_file dnf.out)
		save_indent

		try_call_function "$@" 2>&1 | tee "${TMP_OUT}"

		restore_indent
		ALTERNATIVE_BUFFER_ENABLED=no
		printf '\e[?1049l\e[J\e[1F'

		if [[ ${ERRNO} -eq 0 ]]; then
			info_log "${TITLE}"
			info_note "store output to tempfile: $TMP_OUT"
			return 0
		else
			info_error "${TITLE}"
			cat "${TMP_OUT}"
			return ${ERRNO}
		fi
	else
		control_ci group "DNF run (worker: ${WORKING_CONTAINER}, dnf worker: ${DNF})"
		_run_group
		control_ci groupEnd
	fi
	unset _run_group
}
