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

function _MAIN_exit_handler() {
	local -i _EXIT_CODE=$?
	set +Eeuo pipefail

	_CURRENT_INDENT=''
	SAVED_INDENT=()

	if [[ $ALTERNATIVE_BUFFER_ENABLED != no ]]; then
		printf '\e[?1049l\e[J'
	fi
	printf "\e[0m"

	local CB CMDS
	for CB in "${EXIT_HANDLERS[@]}"; do
		if [[ ${CB:0:1} == '[' ]]; then
			json_array_get_back CMDS "${CB}"
			"${CMDS[@]}"
		else
			"${CB}"
		fi
	done

	if [[ ${_EXIT_CODE} -eq 0 ]]; then
		if [[ ${EXIT_CODE} -ne 0 ]]; then
			_EXIT_CODE=${EXIT_CODE}
		elif [[ ${ERRNO} -ne 0 ]]; then
			_EXIT_CODE=${ERRNO}
		fi
	fi

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		control_ci groupEnd
		control_ci error "bash exit with error code ${_EXIT_CODE}"
		info_warn "script failed, exit code: ${_EXIT_CODE}."
		callstack 1
	elif [[ -n ${INSIDE_GROUP} ]]; then
		control_ci groupEnd
		control_ci error "script success, but last output group is not closed."
	else
		info_note "script success."
	fi

	exit "${_EXIT_CODE}"
}

trap _MAIN_exit_handler EXIT

function _MAIN_cancel_handler() {
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
