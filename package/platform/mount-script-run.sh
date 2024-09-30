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

	ARGS+=("--cap-add=CAP_LINUX_IMMUTABLE")

	# shellcheck disable=SC2086
	indent_stream buildah run "${ARGS[@]}" "--volume=${SCRIPT_FILE}:/tmp/_script:ro" "${CONTAINER}" ${SH} /tmp/_script
	unset WHO_AM_I
}

function export_common_libs() {
	echo 'declare -a EXIT_HANDLERS=()'

	declare -fp filtered_jq parse_json json_array json_array_get_back json_map json_map_get_back
	declare -p JQ_ARGS

	declare -fp die indent dedent x trim indent_stream indent_multiline save_indent restore_indent
	declare -fp info info_note info_log info_warn info_success info_error info_bright
	declare -fp variable_is_array variable_is_map variable_exists is_tty function_exists
	declare -fp use_strict use_normal set_error_trap callstack function_exists reflect_function_location caller_hyperlink
	declare -fp register_exit_handler call_exit_handlers
}

function _warp_script_in_function() {
	local FN_NAME=$1 SCRIPT_DATA=$1

	printf 'function %s {' "${FN_NAME}"
	echo "${DATA}" | sed 's/^/\t/g'
	printf '}\n'
}

## construct_child_shell_script OUTPUT_FILE SCRIPT_FILE [EXTRA_CONTENT]
function construct_child_shell_script() {
	local OUTPUT_FILE="$1" SCRIPT_FILE="$2" EXTRA_CONTENT="${3-}"

	local FIRST_LINE

	read -r FIRST_LINE <"${SCRIPT_FILE}"
	if [[ ${FIRST_LINE} != '#!'* ]]; then
		info_warn "missing shebang in file ${SCRIPT_FILE}"
		FIRST_LINE='#!/usr/bin/bash'
	fi

	local RANDOM_NAME="__pragma_script_once_${RANDOM}__"
	{

		echo "${FIRST_LINE}"

		printf 'if declare -p %s &>/dev/null; then echo "duplicate source to ${BASH_SOURCE[0]}"; exit 1; fi; declare -r %s=yes\n' "${RANDOM_NAME}" "${RANDOM_NAME}"

		printf 'declare -xr SOURCE_SCRIPT_FILE=%q\n' "${SCRIPT_FILE}"
		export_common_libs
		cat_source_file "${COMMON_LIB_ROOT}/staff/script-helpers/tiny-lib.sh"
		SHELL_USE_PROXY

		printf '%s\n' "${EXTRA_CONTENT}"
		if [[ -n ${CI-} ]]; then
			declare -p CI
		else
			echo "unset CI"
		fi
		declare -fp is_ci control_ci
		declare -p _CURRENT_INDENT PROJECT_NAME
		echo '
function try_resolve_file() {
	echo "[in container] ${1} : ${SOURCE_SCRIPT_FILE}"
}
'

		echo 'use_normal'

		cat_source_file "${SCRIPT_FILE}"
	} >"${OUTPUT_FILE}"
}

function cat_source_file() {
	local -r FILE_PATH=$1
	printf '\n## SOURCE FILE: %s\n' "${FILE_PATH}"
	cat "${FILE_PATH}"
	printf '\n'
}
