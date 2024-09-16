declare -a EXIT_HANDLERS=()
declare -i EXIT_CODE=0
declare ALTERNATIVE_BUFFER_ENABLED=no

function register_exit_handler() {
	if [[ $# -eq 1 ]]; then
		EXIT_HANDLERS+=("$1")
	else
		EXIT_HANDLERS+=("$(json_array "$@")")
	fi
}
function call_exit_handlers() {
	local CB
	for CB in "${EXIT_HANDLERS[@]}"; do
		if [[ ${CB:0:1} == '[' ]]; then
			local -a CMDS=()
			json_array_get_back CMDS "${CB}"
			info_note "${CMDS[*]}"
			"${CMDS[@]}"
		else
			"${CB}"
		fi
	done
}

function _MAIN_exit_handler() {
	local -i _EXIT_CODE=$?
	set +x
	set +Eeuo pipefail

	term_reset
	_CURRENT_INDENT='[exit] '

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		info_warn "last command return: ${_EXIT_CODE}."
	elif [[ ${EXIT_CODE} -ne 0 ]]; then
		_EXIT_CODE=${EXIT_CODE}
		info_warn "process exit code: ${EXIT_CODE}."
	elif [[ ${ERRNO} -ne 0 ]]; then
		info_warn "unclean errno: ${ERRNO}."
	fi

	local STACKINFO
	if [[ -e ${ERRSTACK_FILE} ]]; then
		STACKINFO=$(<"${ERRSTACK_FILE}")
	fi

	call_exit_handlers

	if [[ ${_EXIT_CODE} -eq 0 ]]; then
		if [[ ${EXIT_CODE} -ne 0 ]]; then
			_EXIT_CODE=${EXIT_CODE}
		elif [[ ${ERRNO} -ne 0 ]]; then
			_EXIT_CODE=${ERRNO}
		fi
	fi

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		control_ci error "Build Script Error" "bash exit with error code ${_EXIT_CODE}"
		if [[ -n ${STACKINFO} ]]; then
			printf "\e[38;5;1merror stack:\n%s\e[0m\n" "${STACKINFO}"
		else
			STACKINFO=$(callstack 1 2>&1)
			if [[ ${STACKINFO} != *' die()'* ]]; then
				printf "\e[2mexit stack:\n"
				printf '%s\n' "${STACKINFO}"
				printf "\e[0m"
			fi
		fi
	else
		info_note "script success."
	fi

	exit "${_EXIT_CODE}"
}

trap _MAIN_exit_handler EXIT

function _MAIN_cancel_handler() {
	set +x
	_CURRENT_INDENT=''
	SAVED_INDENT=()
	EXIT_CODE=$?
	if [[ ${EXIT_CODE} -eq 0 ]]; then
		if [[ ${ERRNO} -ne 0 ]]; then
			EXIT_CODE=${ERRNO}
		else
			EXIT_CODE=233
		fi
	fi
}
if ! is_ci && is_tty; then
	trap _MAIN_cancel_handler INT
fi

function die() {
	set +e
	trap - ERR

	local LASTERR=$? STACK
	echo -e "\n\e[38;5;9;1mFatalError: $*\e[0m" >&2

	STACK=$(callstack 2 2>&1)
	if [[ ${PRINT_STACK-no} == yes ]]; then
		printf '%s\n' "${STACK}"
	fi

	control_ci error "Build Script Died" "$*"$'\n'"${STACK}"
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
