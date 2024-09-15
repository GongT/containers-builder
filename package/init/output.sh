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
		INSIDE_GROUP=$((INSIDE_GROUP + 1))
		if [[ ${INSIDE_GROUP} -eq 1 ]] && [[ -n ${GITHUB_ACTIONS-} ]]; then
			save_indent
			echo "::group::$*" >&2
		else
			info_bright "[Start Group] $*"
			indent
		fi
		;;
	groupEnd)
		if [[ ${INSIDE_GROUP} -eq 0 ]]; then
			return # must allow, die() rely on this
		fi
		INSIDE_GROUP=$((INSIDE_GROUP - 1))
		if [[ ${INSIDE_GROUP} -eq 0 ]] && [[ -n ${GITHUB_ACTIONS-} ]]; then
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
		echo "failed query $1" >&2
		return 1
	fi
	echo "${INPUT}"
}

function json_map() {
	local -nr VARREF=$1
	if ! variable_is_map "$1"; then
		info_error "variable is not map: $(declare -p "${VARNAME}" 2>&1)"
		return 1
	fi
	local ARGS=()
	for KEY in "${!VARREF[@]}"; do
		ARGS+=("--arg" "${KEY}" "${VARREF[${KEY}]}")
	done
	jq --raw-output --ascii-output --null-input --compact-output --slurp '$ARGS.named' "${ARGS[@]}"
}
function json_map_get_back() {
	local -r VARNAME="$1" JSON="$2"
	if ! variable_is_map "${VARNAME}"; then
		info_error "variable is not map: $(declare -p "${VARNAME}" 2>&1)"
		return 1
	fi

	local SRC
	SRC=$(
		echo "${VARNAME}=("
		echo "${JSON}" | jq --raw-output --compact-output 'to_entries[] | "  [" + (.key|@sh) + "]=" + (.value|@sh)'
		echo ")"
	)
	eval "${SRC}"
}
function json_array() {
	if [[ $# -eq 0 ]]; then
		echo '[]'
		return
	fi
	jq --ascii-output --null-input --compact-output --slurp '$ARGS.positional' --args -- "$@"
}

function json_array_get_back() {
	local -r _VARNAME="$1" JSON="$2"

	if ! variable_is_array "${_VARNAME}"; then
		info_error "variable is not array: $(declare -p "${_VARNAME}" 2>&1)"
		callstack 0
		return 1
	fi

	local -i SIZE i
	local CODE
	CODE=$(jq --null-input --compact-output --raw-output '$ARGS.positional[0]|@sh' --jsonargs "$JSON")
	eval "${_VARNAME}=(${CODE})"
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

function get_cursor_line() {
	is_tty 2 || return 1
	local RESP _ COL
	declare -gi CURSOR_LINE=0

	IFS='[;' read -t 1 -r -s -d 'R' -p $'\e[6n' _ CURSOR_LINE COL
}

function save_cursor_position() {
	is_tty 2 || return 0
	printf '\e[s' >&2
}
function restore_cursor_position() {
	is_tty 2 || return 0
	if ! get_cursor_line; then
		return 0
	fi
	local -i SAVED=${CURSOR_LINE} CLEAR=${1-1}
	printf '\e[u' >&2
	if get_cursor_line && [[ $CURSOR_LINE -gt 1 ]]; then
		if [[ ${CLEAR} -ne 0 ]]; then
			printf '\e[J' >&2
		fi
	else
		printf '\e[%d;1H' ${SAVED} ${SAVED} >&2
		if [[ ${CLEAR} -ne 0 ]]; then
			printf '\e[K' >&2
		fi
	fi
}
function soft_clear() {
	local -i LINES=10
	if ! LINES=$(tput lines); then
		LINES=10
	fi
	for ((i = 1; i < LINES; i++)); do
		printf '\n'
	done
}

function alternative_buffer_execute() {
	local TITLE="$1" RET
	shift

	if ! is_ci && is_tty && [[ ${ALTERNATIVE_BUFFER_ENABLED} == no ]] && [[ ${ALLOW_ALTERNATIVE_BUFFER-yes} == yes ]]; then
		ALTERNATIVE_BUFFER_ENABLED=yes
		local TMP_OUT
		TMP_OUT=$(create_temp_file "screen.output.txt")
		save_cursor_position
		info "save log to ${TMP_OUT}"
		save_indent

		info_warn "$TITLE"
		restore_cursor_position
		{
			stty -echo
			tput smcup
			tput home
			tput ed
		}
		info_log "$TITLE"

		try "$@" &> >(tee "${TMP_OUT}")
		echo "ERRNO=$ERRNO ERRLOCATION=$ERRLOCATION"

		ALTERNATIVE_BUFFER_ENABLED=no
		{
			stty echo
			tput rmcup
			tput ed
		} >&2
		restore_indent

		if [[ ${ERRNO} -eq 0 ]]; then
			collect_temp_file "${TMP_OUT}"
			info_success "[screen] ${TITLE} (command '$*' return ${ERRNO})"
			info_note "[screen]     to see output, set ALLOW_ALTERNATIVE_BUFFER=no"
			return 0
		else
			info_error "[screen:${ERRNO}] ${TITLE}"
			indent_stream cat "${TMP_OUT}"
			info_error "[screen:${ERRNO}] ${TITLE}"
			return ${ERRNO}
		fi
	else
		control_ci group "DNF run (worker: ${WORKING_CONTAINER}, dnf worker: ${DNF})"
		_run_group
		control_ci groupEnd
	fi
	unset _run_group
}
function term_reset() {
	control_ci groupEnd
	{
		stty echo
		tput oc
		tput rs2
		printf '\e[s'
		tput rmcup
		printf '\e[u'
		printf "\r\e[K"
	} >&2
}

function pause() {
	local _ msg=${1-'press any key.'}
	read -r -p "${msg}" _
	tput cuu1
}

function hyperlink() {
	local NAME=$1 URL=$2 ID=${3-}
	if [[ "$ID" ]]; then
		ID="id=$ID"
	fi

	printf '\e[4m\e]8;%s;%s\e\\%s\e]8;;\e\\\e[0m' "$ID" "$URL" "$NAME"
}
