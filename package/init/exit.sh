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
		control_ci error "脚本执行出错" "bash 以 ${_EXIT_CODE} 退出"$'\n'"${STACKINFO}"
		info_warn "最后一条命令返回: ${_EXIT_CODE}.${STACKINFO+ (stack exists)}"
	elif [[ ${EXIT_CODE} -ne 0 ]]; then
		_EXIT_CODE=${EXIT_CODE}
		EXIT_CODE=0

		control_ci error "脚本返回错误" "进程将以错误码 ${_EXIT_CODE} 退出"$'\n'"${STACKINFO}"
		info_warn "进程退出码: ${EXIT_CODE}.${STACKINFO+ (stack exists)}"
	elif [[ ${ERRNO} -ne 0 ]]; then
		_EXIT_CODE=${ERRNO}
		ERRNO=0

		control_ci error "脚本非正常退出" "错误码为 ${_EXIT_CODE}"$'\n'"${STACKINFO}"
		info_warn "脚本非正常退出: ${ERRNO}.${STACKINFO+ (stack exists)}"
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
			control_ci error "脚本清理失败" "脚本清理过程中发生不明错误"
			if [[ -z ${STACKINFO} && -e ${ERRSTACK_FILE} ]]; then
				STACKINFO=$(<"${ERRSTACK_FILE}")
			fi
		fi
	fi

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		if [[ -n ${STACKINFO-} ]]; then
			printf "\e[38;5;1m错误调用栈:\n%s\e[0m\n" "${STACKINFO}"
		else
			STACKINFO=$(callstack 1 2>&1)
			if [[ ${STACKINFO} != *' die()'* ]]; then
				printf "\e[2m退出调用栈:\n"
				printf '%s\n' "${STACKINFO}"
				printf "\e[0m"
			fi
		fi
	else
		info_note "脚本正常结束"
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
	echo -e "\n\e[38;5;9;1m致命错误: $*\e[0m" >&2

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
