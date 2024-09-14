declare -r _BUILDSCRIPT_RUN_STEP_
declare __SOME_STEP_RUN=no
declare -a STEPS_DEFINE=()

function is_recording_steps() {
	[[ ${_BUILDSCRIPT_RUN_STEP_-} == 'none' ]]
}

function skip_this_step() {
	local -r NAME=$1
	local -ir INDEX=${_CURRENT_STAGE_STORE[${NAME}]}
	if [[ -z ${_BUILDSCRIPT_RUN_STEP_} || ${_BUILDSCRIPT_RUN_STEP_} == "${NAME}:${INDEX}" ]]; then
		__SOME_STEP_RUN=yes
		return 1
	else
		return 0
	fi
}

function commit_step_section() {
	if ! is_recording_steps; then
		info_note "  - skip"
		return
	fi

	local NAME=$1 TITLE=$2 PREV_IMAGE=$3 CUR_IMAGE=$4
	local -ir INDEX=${_CURRENT_STAGE_STORE[${NAME}]}
	if [[ -z ${TITLE} ]]; then
		TITLE="No Name Stage"
	fi
	info_note "    ${NAME}:${INDEX} [${TITLE}]"
	info_note "       from: ${PREV_IMAGE}"
	info_note "       tree_base: ${LAST_KNOWN_BASE}"

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
	if [[ ${__SOME_STEP_RUN} == no ]]; then
		ERRNO=233
		info_error "no step have been run"
	fi
}

if is_recording_steps; then
	:
elif [[ -n ${_BUILDSCRIPT_RUN_STEP_+f} ]]; then
	register_exit_handler __check_known_step_title
else
	_BUILDSCRIPT_RUN_STEP_=''
fi
