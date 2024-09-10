#!/usr/bin/env bash

INSIDE_GROUP=
SAVED_INDENT=
export _CURRENT_INDENT=""

function die() {
	control_ci groupEnd
	echo -e "\n\n\x1B[38;5;9;1mFatalError: $*\x1B[0m" >&2
	control_ci error "$*"
	exit 1
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
	case "$ACTION" in
	set-env)
		local -r TMPF="$(create_temp_file)"
		echo "$2" >"$TMPF"
		eval "$1=\"\$(< '$TMPF')\""
		export "${1?}"
		if ! is_ci; then
			return
		elif [[ "${GITHUB_ENV-}" ]]; then
			{
				echo "$1<<EOF"
				echo "$2"
				echo 'EOF'
			} >>"$GITHUB_ENV"
		elif [[ "${GITLAB_ENV-}" ]]; then
			{
				echo "$1=\$( cat <<EOF"
				echo "$2"
				echo 'EOF'
				echo ')'
			} >>"$GITLAB_ENV"
		else
			die "[CI] does not support current ci."
		fi
		;;
	error)
		if [[ "${GITHUB_ACTIONS-}" ]]; then
			echo "::error ::$*" >&2
		fi
		;;
	group)
		if [[ $INSIDE_GROUP ]]; then
			die "not allow nested output group"
		fi
		INSIDE_GROUP=yes
		if [[ "${GITHUB_ACTIONS-}" ]]; then
			SAVED_INDENT=$_CURRENT_INDENT
			_CURRENT_INDENT=
			echo "::group::$*" >&2
		else
			info_bright "[Start Group] $*"
			indent
		fi
		;;
	groupEnd)
		if [[ ! $INSIDE_GROUP ]]; then
			return # must allow, die() rely on this
		fi
		INSIDE_GROUP=
		if [[ "${GITHUB_ACTIONS-}" ]]; then
			_CURRENT_INDENT=$SAVED_INDENT
			SAVED_INDENT=
			echo "::endgroup::" >&2
		else
			dedent
			info_note "[End Group]"
		fi
		;;
	*)
		die "[CI] not support action: $ACTION"
		;;
	esac
}

function callstack() {
	local -i SKIP=${1-1}
	local -i i
	if [[ ${#FUNCNAME[@]} -le $SKIP ]]; then
		echo "  * empty callstack *" >&2
	fi
	for i in $(seq "$SKIP" $((${#FUNCNAME[@]} - 1))); do
		if [[ ${BASH_SOURCE[$((i + 1))]+found} == "found" ]]; then
			echo "  $i: ${BASH_SOURCE[$((i + 1))]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}()" >&2
		else
			echo "  $i: ${FUNCNAME[$i]}()" >&2
		fi
	done
}

function SHELL_ERROR_HANDLER() {
	declare -f callstack
	cat <<'EOF'
_exit_handle_in_container() {
	EXIT_CODE=$?
	set +Eeuo pipefail
	if [[ $EXIT_CODE -ne 0 ]]; then
		echo "bash exit with error code $EXIT_CODE" >&2
		callstack 1
	fi
}
trap _exit_handle_in_container EXIT
EOF
}

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
function info_success() {
	echo -e "$_CURRENT_INDENT\e[38;5;10m$*\e[0m" >&2
}
function info_bright() {
	echo -e "$_CURRENT_INDENT\e[1m$*\e[0m" >&2
}
function info_stream() {
	sed -u "s/^/$_CURRENT_INDENT/" >&2
}

function indent() {
	export _CURRENT_INDENT+="    "
}
function dedent() {
	export _CURRENT_INDENT="${_CURRENT_INDENT:4}"
}

declare -r JQ_ARGS=(--exit-status --compact-output --monochrome-output --raw-output)
function filtered_jq() {
	local INPUT
	INPUT=$(jq "${JQ_ARGS[@]}" "$@")
	if [[ $INPUT == "null" ]]; then
		die "failed query $1"
	fi
	echo "$INPUT"
}

function json_array() {
	if [[ $# -eq 0 ]]; then
		echo '[]'
	fi
	jq --ascii-output --null-input --compact-output --slurp '$ARGS.positional' --args "$@"
}

function json_array_get_back() {
	local -i SIZE i
	local VARNAME="$1" JSON="$2"
	local -a ARR=()
	SIZE=$(echo "$JSON" | jq --compact-output '.|length')
	for ((i = 0; i < SIZE; i++)); do
		ARR+=("$(echo "$JSON" | jq --compact-output --raw-output ".[$i]")")
	done
	eval "$VARNAME=(\"\${ARR[@]}\")"
}

function x() {
	info_note " + ${*}"
	"$@"
}

_LINE_LABEL=""
function branch_split() {
	if [[ "$_LINE_LABEL" ]]; then
		die "tty_split can not call twice"
	fi
	local LABEL=$1
	if ! [[ "$LABEL" ]]; then
		die "empty label"
	fi

	if is_tty; then
		echo -ne "\e[2m  * $LABEL \e[0m" >&2
	fi
}

function branch_join() {
	if ! [[ "$_LINE_LABEL" ]]; then
		die "branch_join without branch_split"
	fi
	local RESULT=$1
	if is_tty; then
		echo -e "\e[2m-> $RESULT\e[0m" >&2
	else
		echo -e "\e[2m$_LINE_LABEL -> $RESULT\e[0m" >&2
	fi
}
