declare -gi ERRNO=233
declare -g ERRLOCATION=''

function callstack() {
	local -i SKIP=${1-1} i
	local F_NAME RESOLVE_ENABLED=no
	if [[ ${#FUNCNAME[@]} -le ${SKIP} ]]; then
		echo "  * empty callstack *" >&2
	fi
	if function_exists try_resolve_file; then
		RESOLVE_ENABLED=yes
	fi
	local -i stack_index
	# stack 0 is this function
	for ((stack_index = SKIP; stack_index < ${#FUNCNAME[@]}; stack_index++)); do
		F_NAME="${BASH_SOURCE[${stack_index}]-}"
		if [[ -z ${F_NAME} ]]; then
			echo "  ${stack_index}: ${FUNCNAME[${stack_index}]}()" >&2
		else
			if [[ $F_NAME == /tmp/_script ]]; then
				F_NAME="${WHO_AM_I-'temporary_script_file.sh'}"
			elif [[ ${RESOLVE_ENABLED} == yes ]]; then
				F_NAME="$(try_resolve_file "${F_NAME}")"
			fi
			echo "  ${stack_index}: ${FUNCNAME[${stack_index}]}() at ${F_NAME}:${BASH_LINENO[$((stack_index - 1))]}" >&2
		fi
	done
	echo "(stack finish)" >&2
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

function reflect_function_location() {
	local FN=$1 DEF_LINE DEF_FILE
	if ! function_exists "$FN"; then
		die "missing bash function: $FN"
	fi
	shopt -s extdebug
	declare -F "${NAME}" | read -r FN DEF_LINE DEF_FILE
	shopt -u extdebug

	if [[ $DEF_FILE != /* ]]; then
		DEF_FILE=$(try_resolve_file "${DEF_FILE}")
	fi
	printf '%s:%d' "${DEF_FILE}" "${DEF_LINE}"
}

function caller_hyperlink() {
	local -i LVL=$1
	LVL+=1

	local NAME=${FUNCNAME[${LVL}]} CAL_LINE=${BASH_LINENO[$((LVL - 1))]} CAL_FILE=${BASH_SOURCE[${LVL}]}

	local DEF_LINE DEF_FILE
	shopt -s extdebug
	declare -F "${NAME}" | read -r NAME DEF_LINE DEF_FILE
	shopt -u extdebug

	if [[ $CAL_FILE != /* ]]; then
		CAL_FILE=$(try_resolve_file "${CAL_FILE}")
	fi
	if [[ $DEF_FILE != /* ]]; then
		DEF_FILE=$(try_resolve_file "${DEF_FILE}")
	fi

	printf '%s (%s) at %s' "${NAME}" "${DEF_FILE}:${DEF_LINE}" "${CAL_FILE}:${CAL_LINE}"
}

function println() {
	printf "\e[2m$1\e[0m\n" "${@:2}" >&2
}
function set_error_trap() {
	# info_note "install global error trap."
	if [[ -n "$(trap -p ERR)" ]]; then
		die "already set ERR trap"
	fi

	local try_symbol=${1-try}

	eval "function ${try_symbol}() { ERRNO=0; \"\$@\"; }"

	declare -g ERRSTACK_FILE
	ERRSTACK_FILE=$(create_temp_file "error.stack.txt")
	readonly ERRSTACK_FILE
	if [[ -e ${ERRSTACK_FILE} ]]; then unlink "${ERRSTACK_FILE}"; fi

	function catch_error_stack() {
		if [[ -e ${ERRSTACK_FILE} ]]; then
			return
		fi
		for I in "${FUNCNAME[@]}"; do
			if [[ ${I} == __try_symbol__ ]]; then
				return
			fi
		done
		# info_warn "error stack captured"
		callstack 2 &>"${ERRSTACK_FILE}" || true
	}

	function ___to_string_global_trap_code() {
		ERRNO=$?
		ERRLOCATION="${FUNCNAME[0]-*no frame*} (${BASH_SOURCE[0]-null source}:${BASH_LINENO[0]-null line})"
		# println '!!ERROR=============================='
		# println 'code=%d, cause: %s, $-: %s' "${ERRNO}" "$BASH_COMMAND" "$-"
		# println '$$=%d, pid=%d, BASH_SUBSHELL=%s' $$ "$BASHPID" "$BASH_SUBSHELL"
		# println 'position: [%s] %s' "${ERRLOCATION}"
		# # println 'dirstack: %s' "$(dirs)"
		# callstack

		if [[ -z ${FUNCNAME+f} ]]; then
			# println '!! main() exit=%d' "${ERRNO}"
			exit ${ERRNO}
		fi
		if [[ ${FUNCNAME[0]} == __try_symbol__ ]]; then
			local __R_CODE=0
			if [[ -e ${ERRSTACK_FILE} ]]; then unlink "${ERRSTACK_FILE}"; fi
			# info_warn "error stack cleard"
		else
			local __R_CODE=${ERRNO}
			catch_error_stack
		fi
		# info_note "return $ERRNO"
		# println '!!ERROR (%d) --------------' "${ERRNO}"
		return ${__R_CODE}
	}

	declare -ga CATCH_ERROR_HERE=()
	declare -gi ERRNO=0 RETURN_TIMES=0
	trap "$(declare -fp ___to_string_global_trap_code | sed -E "/^\S/d; s/^  //g; s/__try_symbol__/${try_symbol}/g")" ERR
	unset -f ___to_string_global_trap_code
}

function use_strict() {
	set -Euo pipefail
	set +e
	shopt -s shift_verbose
	set_error_trap try
}
function use_normal() {
	shopt -s extglob nullglob globstar lastpipe
	use_strict
}
