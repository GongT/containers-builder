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
	trap - ERR

	term_reset
	_CURRENT_INDENT='[exit] '

	local STACKINFO
	if [[ -e ${ERRSTACK_FILE} ]]; then
		STACKINFO=$(<"${ERRSTACK_FILE}")
	fi

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		control_ci error "Script Execute Fail" "bash exit with error code ${_EXIT_CODE}"$'\n'"${STACKINFO}"
		info_warn "last command return: ${_EXIT_CODE}.${STACKINFO+ (stack exists)}"
	elif [[ ${EXIT_CODE} -ne 0 ]]; then
		_EXIT_CODE=${EXIT_CODE}
		EXIT_CODE=0

		control_ci error "Script Return Error" "process will return with error code ${_EXIT_CODE}"$'\n'"${STACKINFO}"
		info_warn "process exit code: ${EXIT_CODE}.${STACKINFO+ (stack exists)}"
	elif [[ ${ERRNO} -ne 0 ]]; then
		_EXIT_CODE=${ERRNO}
		ERRNO=0

		control_ci error "Script Unclean Exit" "something wrong with error code ${_EXIT_CODE}"$'\n'"${STACKINFO}"
		info_warn "unclean errno: ${ERRNO}.${STACKINFO+ (stack exists)}"
	fi

	call_exit_handlers

	if [[ ${_EXIT_CODE} -eq 0 ]]; then
		# error handler throw error
		if [[ ${EXIT_CODE} -ne 0 ]]; then
			_EXIT_CODE=${EXIT_CODE}
		elif [[ ${ERRNO} -ne 0 ]]; then
			_EXIT_CODE=${ERRNO}
		fi
		if [[ ${_EXIT_CODE} -ne 0 ]]; then
			control_ci error "Script Cleanup Failed" "something wrong during script cleanup."
			if [[ -z ${STACKINFO} && -e ${ERRSTACK_FILE} ]]; then
				STACKINFO=$(<"${ERRSTACK_FILE}")
			fi
		fi
	fi

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		if [[ -n ${STACKINFO-} ]]; then
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

	# info_note "last statement."
	exit "${_EXIT_CODE}"
}

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

function use_exit_handler() {
	trap _MAIN_exit_handler EXIT
	if ! is_ci && is_tty; then
		trap _MAIN_cancel_handler INT
	fi
}

function die() {
	set +e
	trap - ERR

	local LASTERR=$? STACK
	echo -e "\n\e[38;5;9;1mFatalError: $*\e[0m" >&2

	if function_exists catch_error_stack; then catch_error_stack; fi

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
