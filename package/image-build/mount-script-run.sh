function buildah_run_shell_script() {
	local CONTAINER SCRIPT_FILE SH="bash"
	if [[ $# -lt 2 ]]; then
		die "buildah_run_shell_script: missing arguments, at least 2, got $#"
	fi

	local ARGS=("$@")
	SCRIPT_FILE=${ARGS[-1]}
	CONTAINER=${ARGS[-2]}
	ARGS=("${ARGS[@]:0:$(($# - 2))}")

	SCRIPT_FILE=$(realpath --no-symlinks --canonicalize-existing "${SCRIPT_FILE}")
	if [[ -x $SCRIPT_FILE ]]; then
		SH=
	else
		HEAD_LINE="$(head -1 "${SCRIPT_FILE}")"
		if [[ $HEAD_LINE == '#!'* ]]; then
			SH=${HEAD_LINE:2}
		fi
	fi

	if [[ -n ${WHO_AM_I-} ]]; then
		ARGS+=("--env=WHO_AM_I=${WHO_AM_I}")
	fi
	ARGS+=("--env=BUILDAH_RUN_HOST_SCRIPT=${SCRIPT_FILE}")

	# shellcheck disable=SC2086
	indent_stream buildah run "${ARGS[@]}" "--volume=${SCRIPT_FILE}:/tmp/_script:ro" "${CONTAINER}" ${SH} /tmp/_script
	unset WHO_AM_I
}

function export_common_libs() {
	echo '
function try_resolve_file() {
	echo "[in container] ${1} : ${SOURCE_SCRIPT_FILE}"
}
declare -a EXIT_HANDLERS=()
'

	declare -fp filtered_jq json_array json_array_get_back json_map json_map_get_back
	declare -p JQ_ARGS

	declare -fp die indent dedent x trim
	declare -fp info info_note info_log info_warn info_success info_error info_bright info_stream
	declare -fp variable_is_array variable_is_map variable_exists is_tty function_exists
	declare -fp use_strict use_normal set_error_trap callstack function_exists reflect_function_location caller_hyperlink
	declare -fp register_exit_handler call_exit_handlers

	cat "${COMMON_LIB_ROOT}/staff/script-helpers/tiny-lib.sh"
}

function export_host_libs() {
	declare -fp uptime_sec timespan_seconds seconds_timespan systemd_service_property
	declare -p microsecond_unit

	echo 'function control_ci() { return; }'
	echo 'declare _CURRENT_INDENT=""'
	cat "${COMMON_LIB_ROOT}/staff/script-helpers/host-lib.sh"
}

function export_guest_libs() {
	if [[ -n ${CI-} ]]; then
		declare -p CI
	else
		echo "unset CI"
	fi
	declare -fp is_ci control_ci
	declare -p _CURRENT_INDENT
}

function construct_child_shell_script() {
	local -r KIND="$1" SCRIPT_FILE="$2" EXTRA_CONTENT="${3-}"
	local -r RANDOM_MAIN="__wrap_script_main_${RANDOM}" RANDOM_PRAGMA="__file_sourced_${RANDOM}"

	local FIRST_LINE DATA
	read -r FIRST_LINE <"${SCRIPT_FILE}"
	if [[ ${FIRST_LINE} == '#!'* ]]; then
		DATA=$(tail -n+2 "${SCRIPT_FILE}")
	else
		info_warn "missing shebang in file ${FIRST_LINE}"
		DATA=$(<"${SCRIPT_FILE}")
		FIRST_LINE='#!/usr/bin/bash'
	fi

	printf '%s\n' "${FIRST_LINE}"
	printf 'function %s {' "${RANDOM_MAIN}"
	printf '%s\n' "${DATA}"
	printf '}\n'

	cat <<-'EOF'
		if [[ -n ${RANDOM_PRAGMA-} ]]; then
			return
		fi
	EOF

	printf 'declare -xr SOURCE_SCRIPT_FILE=%q' "${SCRIPT_FILE}"
	export_common_libs
	SHELL_USE_PROXY

	printf '%s\n' "${EXTRA_CONTENT}"
	if [[ ${KIND} == 'host' ]]; then
		export_host_libs
	elif [[ ${KIND} == 'guest' ]]; then
		export_guest_libs
	else
		die "invalid kind: ${KIND}, should be host/guest"
	fi

	declare -p RANDOM_PRAGMA

	printf 'use_normal\n%s\n' "${RANDOM_MAIN}"
}
