declare -a EXIT_HANDLERS=()
function register_exit_handler() {
	if [[ $# -eq 1 ]]; then
		EXIT_HANDLERS+=("$1")
	else
		EXIT_HANDLERS+=("$(json_array "$@")")
	fi
}
function _exit() {
	local EXIT_CODE=$?
	set +Eeuo pipefail

	echo -ne "\e[0m"

	local CB CMDS
	for CB in "${EXIT_HANDLERS[@]}"; do
		if [[ ${CB:0:1} == '[' ]]; then
			json_array_get_back CMDS "${CB}"
			"${CMDS[@]}"
		else
			"${CB}"
		fi
	done

	if [[ ${EXIT_CODE} -ne 0 ]]; then
		control_ci groupEnd
		control_ci error "bash exit with error code ${EXIT_CODE}"
		info_warn "script failed, exit code: ${EXIT_CODE}."
		callstack 1
	elif [[ -n ${INSIDE_GROUP} ]]; then
		control_ci groupEnd
		control_ci error "script success, but last output group is not closed."
	else
		info_note "script success."
	fi

	exit "${EXIT_CODE}"
}

trap _exit EXIT
