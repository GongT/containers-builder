declare -a _ARG_GETOPT_LONG
declare -a _ARG_GETOPT_SHORT
declare -A _ARG_COMMENT
declare -A _ARG_INPUT
declare -A _ARG_OUTPUT
declare -A _ARG_RESULT
declare -A _ARG_REQUIRE
function arg_string() {
	if [[ "$1" == '+' ]]; then
		shift
		_ARG_REQUIRE[$1]=yes
	fi
	local VAR_NAME=$1 SHORT LONG IN=''
	shift
	_arg_parse_name $1
	shift
	_ARG_COMMENT[$VAR_NAME]="$*"
	declare $VAR_NAME=""
	[[ -n "$LONG" ]] && {
		IN+="/--$LONG"
		_ARG_GETOPT_LONG+=("$LONG:")
		_ARG_OUTPUT["--$LONG"]=$VAR_NAME
	}
	[[ -n "$SHORT" ]] && {
		IN+="/-$SHORT"
		_ARG_GETOPT_SHORT+=("$SHORT:")
		_ARG_OUTPUT["-$SHORT"]=$VAR_NAME
	}
	_ARG_RESULT[$VAR_NAME]=""
	_ARG_INPUT[$VAR_NAME]="${IN:1} <$VAR_NAME>"
}
function arg_flag() {
	local VAR_NAME=$1 SHORT LONG IN=''
	shift
	_arg_parse_name $1
	shift
	_ARG_COMMENT[$VAR_NAME]="$*"
	declare $VAR_NAME=""
	[[ -n "$LONG" ]] && {
		IN+="/--$LONG"
		_ARG_GETOPT_LONG+=("$LONG")
		_ARG_OUTPUT["--$LONG"]=$VAR_NAME
	}
	[[ -n "$SHORT" ]] && {
		IN+="/-$SHORT"
		_ARG_GETOPT_SHORT+=("$SHORT")
		_ARG_OUTPUT["-$SHORT"]=$VAR_NAME
	}
	_ARG_RESULT[$VAR_NAME]=""
	_ARG_INPUT[$VAR_NAME]="${IN:1}"
}
function _check_arg() {
	_PROGRAM_ARGS=("$@")
}
function arg_finish() {
	local ARGS=(--name "$0")
	if [[ -n "${_ARG_GETOPT_LONG[*]}" ]]; then
		local S=''
		for I in "${_ARG_GETOPT_LONG[@]}" ; do
			S+=",$I"
		done
		S=${S:1}
		ARGS+=(--longoptions "$S")
	fi
	if [[ -n "${_ARG_GETOPT_SHORT[*]}" ]]; then
		local S='+'
		for I in "${_ARG_GETOPT_SHORT[@]}" ; do
			S+="$I"
		done
		ARGS+=(--options "$S")
	else
		ARGS+=(--options "")
	fi
	# echo "${ARGS[@]} -- $@"

	if [[ -e "$MONO_ROOT_DIR/environment" ]]; then
		local _PROGRAM_ARGS=()
		eval _check_arg $(
			cat "$MONO_ROOT_DIR/environment" | \
			grep -E "^$PROJECT_NAME" | \
			grep -E "$CURRENT_ACTION" | \
			sed -E 's/^[^:]+:\s*\S+\s*//g'
		) "$@"
	else
		local _PROGRAM_ARGS=("$@")
	fi
	# if [[ ${#_PROGRAM_ARGS[@]} -eq 0 ]]; then
	# 	_PROGRAM_ARGS=()
	# fi
	getopt "${ARGS[@]}" -- "${_PROGRAM_ARGS[@]}" >/dev/null || arg_usage
	eval "_arg_set $(getopt "${ARGS[@]}" -- "${_PROGRAM_ARGS[@]}")"
}
function arg_usage() {
	echo -e "\e[38;5;14mUsage: $0 <options>\e[0m" >&2
	local K
	{
		for K in "${!_ARG_INPUT[@]}" ; do
			echo -e "  \e[2m${_ARG_INPUT[$K]}\e[0m|${_ARG_COMMENT[$K]}"
		done
	} | column -t -c "${COLUMNS-80}" -s '|' >&2
	exit 1
}
function _arg_parse_name() {
	local NAME=$1
	local A=${NAME%%/*} B=${NAME##*/}

	if [[ "$A" == "$B" ]] ; then
		LONG=$A
		SHORT=""
	elif [[ ${#A} -gt ${#B} ]] ; then
		LONG=$A
		SHORT=$B
	else
		LONG=$B
		SHORT=$A
	fi

	if [[ -z "$SHORT" ]] && [[ ${#LONG} -eq 1 ]] ; then
		SHORT=$LONG
		LONG=
	fi

	if ! echo "$LONG$SHORT" | grep -qE "^[0-9a-z_-]+$" ; then
		die "Invalid argument define: $NAME (LONG=$LONG, SHORT=$SHORT)"
	fi

	if [[ ${#SHORT} -gt 1 ]]; then
		die "Short argument only allow single char (LONG=$LONG, SHORT=$SHORT)"
	fi
}
function _arg_set() {
	local VAR_NAME
	while [[ "$1" != "--" ]]; do
		VAR_NAME=${_ARG_OUTPUT[$1]}
		if [[ "${2:0:1}" == "-" ]]; then
			_ARG_RESULT[$VAR_NAME]=yes
		else
			_ARG_RESULT[$VAR_NAME]=$2
			shift
		fi
		shift
	done

	shift
	
	if [[ $# -gt 0 ]]; then
		die "Unknown argument '$1'"
	fi

	for VAR_NAME in "${!_ARG_RESULT[@]}" ; do
		if [[ -z "${_ARG_RESULT[$VAR_NAME]}" ]] && [[ -n "${_ARG_REQUIRE[$VAR_NAME]-}" ]]; then
			die "Argument '${_ARG_INPUT[$VAR_NAME]}' is required"
		fi
		declare -rg "$VAR_NAME=${_ARG_RESULT[$VAR_NAME]}"
	done
	for VAR_NAME in "${!_ARG_RESULT[@]}" ; do
		echo -e "\e[2m$VAR_NAME=${_ARG_RESULT[$VAR_NAME]}\e[0m" >&2
	done
}
