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

# 用法:
# setup_systemd <cache_branch> \
#    <plugin1> [PARAM1=VALUE1] [PARAM2=VALUE2] ... \
#    <plugin2> [PARAM1=VALUE1] [PARAM2=VALUE2] ...
function setup_systemd() {
	local STEP="配置镜像中的systemd"
	local CACHE_BRANCH="$1"
	shift

	local __hash_cb __build_cb

	local PLUGIN_LIST=()
	local PARAMS_LIST=()
	local -a INPUT_ARGS=("$@")

	function __hash_cb() {
		if [[ ${#INPUT_ARGS[@]} -eq 0 || ${INPUT_ARGS[0]} != 'basic' ]]; then
			# 第一个参数不是basic，按需追加basic参数
			if [[ -n $(image_get_label "${PREV_STAGE_IMAGE_ID}" "${LABELID_USE_SYSTEMD}") ]]; then
				# 如果有此label，说明镜像前面的层已经有systemd设置
				info_note "[systemd] 镜像已经设置过systemd"
			else
				info_note "[systemd] 本镜像首次添加systemd，前置 <basic> 组件"
				INPUT_ARGS=("basic" "${INPUT_ARGS[@]}")
			fi
		fi

		if [[ ${#INPUT_ARGS[@]} -eq 0 ]]; then
			die "[systemd] 无事可做！"
		fi

		echo "version:4+${THIS_FILE_HASH}"
		set -- "${INPUT_ARGS[@]}"

		control_ci group "---- [systemd] 检查阶段:"
		while [[ $# -gt 0 ]]; do
			local PLUGIN="$1" PARAMS=() PARAMS_JSON='' VERSION=''
			shift

			if ! is_systemd_plugin "${PLUGIN}"; then
				die "缺失 systemd 组件: ${PLUGIN}"
			fi
			VERSION=$(tr -d '\n' <"${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/version.txt")

			while [[ $# -gt 0 ]]; do
				local PARAM=$1

				if is_systemd_plugin "${PARAM}"; then
					break
				fi
				if ! validate_systemd_plugin_param "${PARAM}"; then
					die "无效参数: ${PARAM} (组件: ${PLUGIN})"
				fi
				shift
				PARAMS+=("${PARAM}")
			done

			PARAMS_JSON="$(json_array "${PARAMS[@]}")"
			info_note "组件 ${PLUGIN}, 版本: ${VERSION}, 参数: '${PARAMS_JSON}'"
			printf "plugin: %s, version: %s, params: %s\n" "${PLUGIN}" "${VERSION}" "${PARAMS_JSON}"

			PLUGIN_LIST+=("${PLUGIN}")
			PARAMS_LIST+=("${PARAMS_JSON}")
		done
		control_ci groupEnd

		declare -r PLUGIN_LIST
		declare -r PARAMS_LIST
	}
	function __build_cb() {
		local CONTAINER="$1"

		local PLUGIN=''
		local -a PARAMS
		local -i INDX

		info_note "---- [systemd] 执行阶段:"
		for ((INDX = 0; INDX < "${#PLUGIN_LIST[@]}"; INDX++)); do
			PLUGIN="${PLUGIN_LIST[${INDX}]}"
			json_array_get_back PARAMS "${PARAMS_LIST[${INDX}]}"

			local FILES="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/fs"
			local CONFIG_SRC="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/config.sh"
			local SETUP_SRC="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/setup.sh"
			local SETUP_ARGS=()
			local -i ACT=0

			control_ci group "设置组件 ${PLUGIN}"
			if [[ -d ${FILES} ]]; then
				ACT+=1
				info_log " -> 复制文件系统"
				buildah copy "${CONTAINER}" "${FILES}" "/"
			fi
			if [[ -e ${CONFIG_SRC} ]]; then
				ACT+=1
				info_log " -> 执行 config.sh"

				function add_setup_arg() {
					SETUP_ARGS+=("$@")
				}

				# shellcheck source=/dev/null
				source "${CONFIG_SRC}" "${CONTAINER}" "${PARAMS[@]}"

				unset add_setup_arg
			fi
			if [[ -e ${SETUP_SRC} ]]; then
				ACT+=1
				info_log " -> 执行 setup.sh"
				local I TMPF
				TMPF=$(create_temp_file "setup.systemd.${PLUGIN}.sh")

				local EXTRA
				EXTRA=$(
					printf 'declare -x WHO_AM_I=%q\n' "${SETUP_SRC}"
					if [[ ${#PARAMS[@]} -gt 0 ]]; then
						printf 'declare -xr %q\n' "${PARAMS[@]}"
					fi
					cat "${COMMON_LIB_ROOT}/staff/script-helpers/systemd-setup-lib.sh"
				)
				construct_child_shell_script "${TMPF}" "${SETUP_SRC}" "${EXTRA}"

				buildah_run_shell_script \
					"${SETUP_ARGS[@]}" \
					"${CONTAINER}" "${TMPF}"
			fi

			if [[ $ACT -eq 0 ]]; then
				die "组件未定义操作: ${PLUGIN}"
			fi
			control_ci groupEnd
		done
		info_note "setup_systemd 完成"
	}

	export BUILDAH_HISTORY=false
	buildah_cache "${CACHE_BRANCH}" __hash_cb __build_cb
	unset BUILDAH_HISTORY
	SYSTEMD_PLUGINS=()
}
