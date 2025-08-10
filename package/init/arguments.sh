declare -a _ARG_GETOPT_LONG
declare -a _ARG_GETOPT_SHORT
declare -A _ARG_COMMENT
declare -A _ARG_DEFAULT
declare -A _ARG_INPUT
declare -A _ARG_OUTPUT
declare -A _ARG_RESULT
declare -A _ARG_REQUIRE
declare -g _ARG_HAS_FINISH=no
function arg_string() {
	_ARG_USING=yes
	if [[ $1 == '+' ]]; then
		shift
		_ARG_REQUIRE[$1]=yes
		if [[ $1 == *=* ]]; then
			die "required argument must not have default value"
		fi
	elif [[ $1 == '-' ]]; then
		shift
	fi
	local VAR_NAME=$1 SHORT LONG IN=''

	if [[ ${VAR_NAME} == *=* ]]; then
		local VAR_NAME=${VAR_NAME%%=*} DEFAULT_VAL=${VAR_NAME#*=}
		_ARG_DEFAULT[${VAR_NAME}]="${DEFAULT_VAL}"
	elif [[ -n ${!VAR_NAME-} ]]; then
		_ARG_DEFAULT[${VAR_NAME}]="${!VAR_NAME}"
	fi

	shift
	_arg_parse_name "$1"
	shift
	_ARG_COMMENT[${VAR_NAME}]="$*"
	[[ -n ${LONG} ]] && {
		IN+="/--${LONG}"
		_ARG_GETOPT_LONG+=("${LONG}:")
		_ARG_OUTPUT["--${LONG}"]=${VAR_NAME}
	}
	[[ -n ${SHORT} ]] && {
		IN+="/-${SHORT}"
		_ARG_GETOPT_SHORT+=("${SHORT}:")
		_ARG_OUTPUT["-${SHORT}"]=${VAR_NAME}
	}
	if [[ ${!VAR_NAME+found} != found ]]; then
		declare "${VAR_NAME}="
	fi
	_ARG_INPUT[${VAR_NAME}]="${IN:1} <${VAR_NAME}>"
}
function arg_flag() {
	_ARG_USING=yes
	local VAR_NAME=$1 SHORT LONG IN=''
	shift
	_arg_parse_name "$1"
	shift
	_ARG_COMMENT[${VAR_NAME}]="$*"
	declare "${VAR_NAME}="
	[[ -n ${LONG} ]] && {
		IN+="/--${LONG}"
		_ARG_GETOPT_LONG+=("${LONG}")
		_ARG_OUTPUT["--${LONG}"]=${VAR_NAME}
	}
	[[ -n ${SHORT} ]] && {
		IN+="/-${SHORT}"
		_ARG_GETOPT_SHORT+=("${SHORT}")
		_ARG_OUTPUT["-${SHORT}"]=${VAR_NAME}
	}
	_ARG_RESULT[${VAR_NAME}]=""
	_ARG_INPUT[${VAR_NAME}]="${IN:1}"
}
function _arg_ensure_finish() {
	if [[ ${_ARG_HAS_FINISH} == "yes" ]]; then
		return
	fi
	if [[ ${_ARG_USING+found} == found ]] && [[ ${BASH_SUBSHELL} -ne 0 ]]; then
		die "invalid usage, some function has drop into a subshell, use arg_finish before it."
	fi
	arg_finish >&2
}
function arg_finish() {
	if [[ ${_ARG_HAS_FINISH} == "yes" ]]; then
		die "Error: arg_finish called twice!"
	fi
	declare -gr _ARG_HAS_FINISH=yes

	local ARGS=(--name "$0")
	if [[ -n ${_ARG_GETOPT_LONG[*]} ]]; then
		local S=''
		for I in "${_ARG_GETOPT_LONG[@]}"; do
			S+=",${I}"
		done
		S=${S:1}
		ARGS+=(--longoptions "${S}")
	fi
	if [[ -n ${_ARG_GETOPT_SHORT[*]} ]]; then
		local S='+'
		for I in "${_ARG_GETOPT_SHORT[@]}"; do
			S+="${I}"
		done
		ARGS+=(--options "${S}")
	else
		ARGS+=(--options "")
	fi
	# println "${ARGS[@]} -- $@"

	local _PROGRAM_ARGS=()
	local USER_PRIVATE_CONFIG_FILE="${MONO_ROOT_DIR:-not set}/environment"
	if [[ ! -e ${USER_PRIVATE_CONFIG_FILE} ]]; then
		USER_PRIVATE_CONFIG_FILE="${HOME}/environment"
	fi

	if [[ -e ${USER_PRIVATE_CONFIG_FILE} ]]; then
		info_note "load arguments from ${USER_PRIVATE_CONFIG_FILE} - ${CURRENT_ACTION}"
		local -a ENV_ARGS CMDLINE_TO_PARSE
		CMDLINE_TO_PARSE=$(
			grep_safe -E "^${PROJECT_NAME}:" "${USER_PRIVATE_CONFIG_FILE}"  \
				| grep_safe -E "${CURRENT_ACTION}" \
				| sed -E 's/^[^:]+:\s*\S+\s*//g'
		)
		mapfile -t ENV_ARGS < <(echo "${CMDLINE_TO_PARSE}" | xargs --no-run-if-empty -n1 printf "%s\n")
		_PROGRAM_ARGS+=("${ENV_ARGS[@]}")

		local ENV_VARS
		ENV_VARS=$(grep_safe -E '^declare ' "${USER_PRIVATE_CONFIG_FILE}" | sed 's#^declare #declare -g #g')
		info_warn "${ENV_VARS}"
		if [[ -n "${ENV_VARS}" ]]; then
			eval "${ENV_VARS}"
		fi
	else
		info_note "environment file not exists: ${USER_PRIVATE_CONFIG_FILE}"
	fi

	for i in $(seq $((${#__BASH_ARGV[@]} - 1)) -1 0); do
		_PROGRAM_ARGS+=("${__BASH_ARGV[${i}]}")
	done

	local E
	E=$(getopt "${ARGS[@]}" -- "${_PROGRAM_ARGS[@]}" 2>&1 >/dev/null || true)
	if [[ -n ${E} ]]; then
		die "${E}"
	fi
	# println "ARGS=${ARGS[*]}"
	# println "_PROGRAM_ARGS=${_PROGRAM_ARGS[*]}"
	eval "_arg_set $(getopt "${ARGS[@]}" -- "${_PROGRAM_ARGS[@]}")"

	if [[ ${_ACTION_HELP} == "yes" ]]; then
		arg_get_usage
		exit 0
	fi
}
function arg_print_usage() {
	arg_get_usage >&2
	exit 1
}
function arg_get_usage() {
	info "Usage: $0 <options>"
	local K
	{
		for K in "${!_ARG_INPUT[@]}"; do
			echo -e "  \e[2m${_ARG_INPUT[${K}]}\e[0m|${_ARG_COMMENT[${K}]}"
		done
	} | column -t -c "${COLUMNS-80}" -s '|' >&2
}
function _arg_parse_name() {
	local NAME=$1
	local A=${NAME%%/*} B=${NAME##*/}

	if [[ ${A} == "${B}" ]]; then
		LONG=${A}
		SHORT=""
	elif [[ ${#A} -gt ${#B} ]]; then
		LONG=${A}
		SHORT=${B}
	else
		LONG=${B}
		SHORT=${A}
	fi

	if [[ -z ${SHORT} ]] && [[ ${#LONG} -eq 1 ]]; then
		SHORT=${LONG}
		LONG=
	fi

	if ! echo "${LONG}${SHORT}" | grep -qE "^[0-9a-z_-]+$"; then
		die "Invalid argument define: ${NAME} (LONG=${LONG}, SHORT=${SHORT})"
	fi

	if [[ ${#SHORT} -gt 1 ]]; then
		die "Short argument only allow single char (LONG=${LONG}, SHORT=${SHORT})"
	fi
}
function _arg_set() {
	local VAR_NAME
	while [[ $1 != "--" ]]; do
		VAR_NAME=${_ARG_OUTPUT[$1]}
		if [[ ${2:0:1} == "-" ]]; then
			_ARG_RESULT[${VAR_NAME}]=yes
		else
			_ARG_RESULT[${VAR_NAME}]=$2
			shift
		fi
		shift
	done

	shift

	if [[ $# -gt 0 ]]; then
		die "Unknown argument '$1'"
	fi

	for VAR_NAME in "${!_ARG_INPUT[@]}"; do
		if [[ -z ${_ARG_RESULT[${VAR_NAME}]-} && -n ${_ARG_REQUIRE[${VAR_NAME}]-} ]]; then
			die "Argument '${_ARG_INPUT[${VAR_NAME}]} - ${_ARG_COMMENT[${VAR_NAME}]-}' is required"
		fi
		if [[ ${_ARG_RESULT[${VAR_NAME}]+found} == found ]]; then
			declare -rg "${VAR_NAME}=${_ARG_RESULT[${VAR_NAME}]}"
		elif [[ ${_ARG_DEFAULT[${VAR_NAME}]+found} == found ]]; then
			declare -rg "${VAR_NAME}=${_ARG_DEFAULT[${VAR_NAME}]}"
		else
			unset "${VAR_NAME}"
		fi
	done
	{
		printf "\e[2m"
		for VAR_NAME in "${!_ARG_INPUT[@]}"; do
			printf "%s=%s\n" "${VAR_NAME}" "${!VAR_NAME:-*unset*}"
		done
		printf "\e[0m"
	} >&2
}
function split_assign_argument_value() {
	printf '%s' "${1#*=}"
}
function split_assign_argument_key() {
	printf '%s' "${1%%=*}"
}
function is_long_argument() {
	[[ ${1:0:2} == '--' && ${#1} -gt 2 ]]
}
function is_short_argument() {
	[[ ${1:0:1} == '-' && ${1:1:1} != '-' && ${1:1:1} != '=' && ${#1} -gt 1 ]]
}
function is_combind_short_argument() {
	is_short_argument "$1" && [[ ${#1} -gt 2 && ${1:2:1} != '=' ]]
}
function is_assign_argument() {
	[[ $1 == -*=* ]]
}
function is_flag_argument() {
	[[ $1 == -* && $1 != -*=* ]]
}

arg_flag _ACTION_HELP help "show help"
