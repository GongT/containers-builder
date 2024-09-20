THIS_FILE_HASH=$(md5sum "${BASH_SOURCE[0]}" | awk '{print $1}')

function is_systemd_plugin() {
	local PLUGIN=$1
	[[ -f "${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/version.txt" ]] \
		&& [[ -f "${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/setup.sh" || -f "${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/config.sh" ]]
}
function validate_systemd_plugin_param() {
	local VARDEF=$1
	if [[ ${VARDEF} != *=* ]]; then
		return 1
	fi
	local VARNAME=${VARDEF%%=*}

	if [[ ${VARNAME^^} != "${VARNAME}" ]]; then
		die "systemd define variable must uppercase (${VARNAME})"
	fi
}

function setup_systemd() {
	local STEP="配置镜像中的systemd"
	local CACHE_BRANCH="$1"
	shift

	local __hash_cb __build_cb

	local PLUGIN_LIST=()
	local PARAMS_LIST=()
	local -a INPUT_ARGS=("$@")

	if [[ ${#INPUT_ARGS[@]} -eq 0 || ${INPUT_ARGS[0]} != 'basic' ]]; then
		INPUT_ARGS=("basic" "${INPUT_ARGS[@]}")
	fi

	function __hash_cb() {
		echo "version:4+${THIS_FILE_HASH}"
		set -- "${INPUT_ARGS[@]}"

		info_note "check systemd:"
		indent
		while [[ $# -gt 0 ]]; do
			local PLUGIN="$1" PARAMS=() PARAMS_JSON='' VERSION=''
			shift

			if ! is_systemd_plugin "${PLUGIN}"; then
				die "missing systemd plugin: ${PLUGIN}"
			fi
			VERSION=$(tr -d '\n' <"${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/version.txt")

			while [[ $# -gt 0 ]]; do
				local PARAM=$1

				if is_systemd_plugin "${PARAM}"; then
					break
				fi
				if ! validate_systemd_plugin_param "${PARAM}"; then
					die "invalid parameter: ${PARAM} (plugin: ${PLUGIN})"
				fi
				shift
				PARAMS+=("${PARAM}")
			done

			PARAMS_JSON="$(json_array "${PARAMS[@]}")"
			info_note "using ${PLUGIN}, version: ${VERSION}, arguments: '${PARAMS_JSON}'"
			printf "plugin: %s, version: %s, params: %s\n" "${PLUGIN}" "${VERSION}" "${PARAMS_JSON}"

			PLUGIN_LIST+=("${PLUGIN}")
			PARAMS_LIST+=("${PARAMS_JSON}")
		done
		dedent

		declare -r PLUGIN_LIST
		declare -r PARAMS_LIST
	}
	function __build_cb() {
		local CONTAINER="$1"

		local PLUGIN=''
		local -a PARAMS
		local -i INDX

		info "setup systemd:"
		indent
		for ((INDX = 0; INDX < "${#PLUGIN_LIST[@]}"; INDX++)); do
			PLUGIN="${PLUGIN_LIST[${INDX}]}"
			json_array_get_back PARAMS "${PARAMS_LIST[${INDX}]}"

			local FILES="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/fs"
			local CONFIG_SRC="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/config.sh"
			local SETUP_SRC="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/setup.sh"
			local SETUP_ARGS=()
			local -i ACT=0

			info_log "setup ${PLUGIN}"
			if [[ -d ${FILES} ]]; then
				ACT+=1
				info_log " -> copy filesystem"
				buildah copy "${CONTAINER}" "${FILES}" "/"
			fi
			if [[ -e ${CONFIG_SRC} ]]; then
				ACT+=1
				info_log " -> prepare run"

				function add_setup_arg() {
					SETUP_ARGS+=("$@")
				}

				# shellcheck source=/dev/null
				source "${CONFIG_SRC}" "${CONTAINER}" "${PARAMS[@]}"

				unset add_setup_arg
			fi
			if [[ -e ${SETUP_SRC} ]]; then
				ACT+=1
				info_log " -> execute setup"
				local I TMPF
				TMPF=$(create_temp_file "setup.systemd.${PLUGIN}.sh")

				local EXTRA
				EXTRA=$(
					printf 'declare -xr WHO_AM_I=%q\n' "${SETUP_SRC}"
					if [[ ${#PARAMS[@]} -gt 0 ]]; then
						printf 'declare -xr %q\n' "${PARAMS[@]}"
					fi
				)
				construct_child_shell_script "${TMPF}" "${SETUP_SRC}" "${EXTRA}"

				buildah_run_shell_script \
					"${SETUP_ARGS[@]}" \
					"${CONTAINER}" "${TMPF}"
			fi

			if [[ $ACT -eq 0 ]]; then
				die "plugin have no action: ${PLUGIN}"
			fi
		done
		dedent
		info_note "setup systemd done."
	}

	export BUILDAH_HISTORY=false
	buildah_cache "${CACHE_BRANCH}" __hash_cb __build_cb
	unset BUILDAH_HISTORY
	SYSTEMD_PLUGINS=()
}
