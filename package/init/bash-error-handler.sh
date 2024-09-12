function callstack() {
	local -i SKIP=${1-1} i
	local FN RESOLVE_ENABLED=no
	if [[ ${#FUNCNAME[@]} -le ${SKIP} ]]; then
		echo "  * empty callstack *" >&2
	fi
	if is_bash_function try_resolve_file; then
		RESOLVE_ENABLED=yes
	fi
	local -i stack_index
	# stack 0 is this function
	for ((stack_index = SKIP; stack_index < ${#FUNCNAME[@]}; stack_index++)); do
		FN="${BASH_SOURCE[${stack_index}]-}"
		if [[ -z ${FN} ]]; then
			echo "  ${stack_index}: ${FUNCNAME[${stack_index}]}()" >&2
		else
			if [[ $FN == /tmp/_script ]]; then
				FN="${WHO_AM_I-'temporary_script_file.sh'}"
			elif [[ ${RESOLVE_ENABLED} == yes ]]; then
				FN="$(try_resolve_file "${FN}")"
			fi
			echo "  ${stack_index}: ${FUNCNAME[${stack_index}]}() at ${FN}:${BASH_LINENO[${stack_index}]}" >&2
		fi
	done
}

function try_resolve_file() {
	local i PATHS=(
		"${COMMON_LIB_ROOT}"
		"${COMMON_LIB_ROOT}/package"
		"${CURRENT_DIR}"
	)
	if [[ -n ${MONO_ROOT_DIR-} ]]; then
		PATHS+=("${MONO_ROOT_DIR}")
	fi
	for i in "${PATHS[@]}"; do
		if [[ -f "${i}/$1" ]]; then
			realpath -m "${i}/$1"
			return
		fi
	done
	printf "%s" "$1"
}

function global_error_trap() {
	local -i _ERRNO=$?

	# println "cause: $BASH_COMMAND | search: ${CATCH_ERROR_HERE[*]} | stack: ${FUNCNAME[*]}"

	if [[ ${RETURN_TIMES} -gt 0 ]]; then
		RETURN_TIMES=$((RETURN_TIMES - 1))
		println "   -> return $RETURN_TIMES times."
		if [[ $RETURN_TIMES -eq 0 ]]; then
			return 0
		fi
		return $ERRNO
	fi
	ERRNO=${_ERRNO}

	if [[ ${#CATCH_ERROR_HERE[@]} -gt 0 ]]; then
		if [[ ${FUNCNAME[1]} == "try_call_function" ]]; then
			return 0
		fi

		local -i stack_index
		# stack 0 is this function
		for ((stack_index = 1; stack_index < ${#FUNCNAME[@]}; stack_index++)); do
			# println "walk stack: %s" "${FUNCNAME[$stack_index]}"
			if [[ ${FUNCNAME[$stack_index]} == "${CATCH_ERROR_HERE[0]}" ]]; then
				RETURN_TIMES=$((stack_index - 1))
				# println "found catch, return $RETURN_TIMES times."
				if [[ $RETURN_TIMES -eq 0 ]]; then
					return 0
				fi
				return $ERRNO
			fi
		done
	fi

	die "Unhandle Script Error: $ERRNO"
}
function set_error_trap() {
	info_note "install global error trap."
	if [[ -n "$(trap -p ERR)" ]]; then
		die "already set ERR trap"
	fi

	declare -ga CATCH_ERROR_HERE=()
	declare -gi ERRNO=0 RETURN_TIMES=0
	trap 'global_error_trap $LINENO ; return $?' ERR
}
function is_bash_function() {
	declare -fp "$1" &>/dev/null
}
function try_call_function() {
	local FN=$1
	if ! is_bash_function "$FN"; then
		die "missing bash function: $FN"
	fi

	CATCH_ERROR_HERE=("$1" "${CATCH_ERROR_HERE[@]}")
	"$@"
	CATCH_ERROR_HERE=("${CATCH_ERROR_HERE[@]:1}")
}
