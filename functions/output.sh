#!/usr/bin/env bash

INSIDE_GROUP=
SAVED_INDENT=
export _CURRENT_INDENT=""

function die() {
	control_ci groupEnd
	echo -e "Error: $*\n\e[2m$(callstack)\e[0m" >&2
	control_ci error "$*"
	exit 1
}

function control_ci() {
	local -r ACTION="$1"
	shift
	# info_log "[CI] Action=$ACTION, Args=$*" >&2
	case "$ACTION" in
	set-env)
		local -r TMPF="$(mktemp)"
		echo "$2" >"$TMPF"
		eval "$1=\"\$(< '$TMPF')\""
		export "$1"
		if ! is_ci; then
			return
		elif [[ "${GITHUB_ENV:-}" ]]; then
			{
				echo "$1<<EOF"
				echo "$2"
				echo 'EOF'
			} >>"$GITHUB_ENV"
		elif [[ "${GITLAB_CI:-}" ]]; then
			if [[ "${GITLAB_ENV:-}" ]]; then
				{
					echo "$1=\$( cat <<EOF"
					echo "$2"
					echo 'EOF'
					echo ')'
				} >>"$GITLAB_ENV"
			fi
		else
			die "[CI] does not support current ci."
		fi
		;;
	error)
		if [[ "${GITHUB_ACTIONS:-}" ]]; then
			echo "::error ::$*" >&2
		else
			echo "[CI] Error $*" >&2
		fi
		;;
	group)
		if [[ $INSIDE_GROUP ]]; then
			die "not allow nested output group"
		fi
		INSIDE_GROUP=yes
		SAVED_INDENT=$_CURRENT_INDENT
		_CURRENT_INDENT=
		if [[ "${GITHUB_ACTIONS:-}" ]]; then
			echo "::group::$*" >&2
		fi
		;;
	groupEnd)
		if [[ ! $INSIDE_GROUP ]]; then
			return
		fi
		_CURRENT_INDENT=$SAVED_INDENT
		SAVED_INDENT=
		INSIDE_GROUP=
		if [[ "${GITHUB_ACTIONS:-}" ]]; then
			echo "::endgroup::" >&2
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

function _exit_handle_output() {
	echo -ne "\e[0m"
	if [[ $EXIT_CODE -ne 0 ]]; then
		control_ci groupEnd
		control_ci error "bash exit with error code $EXIT_CODE"
		callstack 1
	elif [[ $INSIDE_GROUP ]]; then
		control_ci groupEnd
		control_ci error "last output group is not finished."
	fi
}
register_exit_handler _exit_handle_output

function SHELL_ERROR_HANDLER() {
	declare -f callstack
	echo '
_exit_handle_in_container() {
	EXIT_CODE=$?
	set +Eeuo pipefail
	if [[ $EXIT_CODE -ne 0 ]]; then
		echo "bash exit with error code $EXIT_CODE" >&2
		callstack 1
	fi
}
	trap _exit_handle_in_container EXIT
'
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

function indent() {
	export _CURRENT_INDENT+="    "
}
function dedent() {
	export _CURRENT_INDENT="${_CURRENT_INDENT:4}"
}

function x() {
	info_note " + ${*}"
	"$@"
}
