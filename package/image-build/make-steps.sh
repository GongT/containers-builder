# '' - 正常生成
# none - 跳过所有步骤
# xxx:3 - 只运行cacheid是xxx的第3个步骤
declare _BUILDSCRIPT_RUN_STEP_ # no =

declare __SOME_STEP_RUN=no
declare -a STEPS_DEFINE=()

function is_recording_steps() {
	[[ ${_BUILDSCRIPT_RUN_STEP_} == 'none' ]]
}
function is_normal_running() {
	[[ ${_BUILDSCRIPT_RUN_STEP_} == '' ]]
}

function skip_this_step() {
	local -r NAME=$1
	local -ir INDEX=${_CURRENT_STAGE_STORE[${NAME}]}
	if is_normal_running || [[ ${_BUILDSCRIPT_RUN_STEP_} == "${NAME}:${INDEX}" ]]; then
		__SOME_STEP_RUN=yes
		return 1
	else
		return 0
	fi
}

function should_quit_after_this_step() {
	! is_normal_running && ! is_recording_steps && [[ ${__SOME_STEP_RUN} == yes ]]
}

function commit_step_section() {
	if ! is_recording_steps; then
		info_note "  - 跳过"
		return
	fi

	local NAME=$1 TITLE=$2 PREV_IMAGE=$3 CUR_IMAGE=$4
	local -ir INDEX=${_CURRENT_STAGE_STORE[${NAME}]}
	if [[ -z ${TITLE} ]]; then
		TITLE="未命名步骤"
	fi
	info_note "    ${NAME}:${INDEX} [${TITLE}]"
	info_note "       构建自: ${PREV_IMAGE}"
	info_note "       基础镜像: ${LAST_KNOWN_BASE}"

	local -A DEF=(
		[name]="${NAME}"
		[index]="${INDEX}"
		[title]="${TITLE}"
		[prev_image]="${PREV_IMAGE}"
		[cur_image]="${CUR_IMAGE}"
	)
	STEPS_DEFINE+=("$(json_map DEF)")
}

function __check_known_step_title() {
	if [[ ${ERRNO} -eq 0 ]] && [[ ${__SOME_STEP_RUN} == no ]]; then
		ERRNO=233
		info_error "没有步骤被执行"
	fi
}

function __print_steps_summary() {
	info "综合:"
	info_log "    基础镜像: ${BASE_IMAGE_NAME-*missing*}"
	info "记录的步骤:"
	for JSON in "${STEPS_DEFINE[@]}"; do
		local -A STEPDEF=()
		json_map_get_back "STEPDEF" "${JSON}"
		info_log "[${STEPDEF[name]}:${STEPDEF[index]}] ${STEPDEF[title]}"
		info_note "    构建自: ${STEPDEF[prev_image]}"
		info_note "    基础镜像: ${STEPDEF[cur_image]}"
	done
}

if [[ -z ${_BUILDSCRIPT_RUN_STEP_-} ]]; then
	info "[run mode] 完整构建"
	_BUILDSCRIPT_RUN_STEP_=''
elif is_recording_steps; then
	info "[run mode] 记录步骤"
	register_exit_handler __print_steps_summary
else
	info "[run mode] 单步构建 ($_BUILDSCRIPT_RUN_STEP_)"
	register_exit_handler __check_known_step_title
fi

function record_last_image() {
	if [[ $1 == -f ]]; then
		control_ci set-env "LAST_BUILT_IMAGE_ID" "$2"
		return
	fi
	local _ID=$1

	if ! is_long_digits "${_ID}" && [[ ${_ID} != 'scratch' ]]; then
		_ID=$(image_get_long_id "${_ID}")
	fi

	control_ci set-env "LAST_BUILT_IMAGE_ID" "${_ID}"
	control_ci set-env "LAST_CACHE_COMES_FROM" "${LAST_CACHE_COMES_FROM}"
}
function get_last_image_id() {
	if variable_exists LAST_BUILT_IMAGE_ID; then
		printf '%s' "${LAST_BUILT_IMAGE_ID}"
	else
		info_error "没有上一步的镜像 ID"
		return 1
	fi
}

KNOWN_BASE_IMAGES=()
function record_last_base_name() {
	local -r NAME=$1
	KNOWN_BASE_IMAGES+=("${NAME}")
	control_ci set-env "BASE_IMAGE_NAME" "${NAME}"
}

function get_last_base_name() {
	if variable_exists BASE_IMAGE_NAME; then
		printf '%s' "${BASE_IMAGE_NAME}"
	else
		info_error "没有已知的基础镜像 ID"
		return 1
	fi
}
