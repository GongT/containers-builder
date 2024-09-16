#!/usr/bin/env bash

declare -A _CURRENT_STAGE_STORE=()
declare LAST_CACHE_COMES_FROM=build # or pull

function buildah_cache_increament_count() {
	local NAME=$1
	local TITLE=$2
	if [[ ${_CURRENT_STAGE_STORE[${NAME}]+found} == 'found' ]]; then
		DONE_STAGE="${_CURRENT_STAGE_STORE[${NAME}]}"
		WORK_STAGE="${DONE_STAGE} + 1"
	else
		DONE_STAGE=0
		WORK_STAGE=1
	fi
	_CURRENT_STAGE_STORE[${NAME}]=${WORK_STAGE}
}

# buildah_cache "$PREVIOUS_ID" hash_function build_function
# build_function <RESULT_CONTAINER_NAME>
function buildah_cache() {
	local _STITLE=""
	if [[ ${STEP+found} == found ]]; then
		_STITLE="${STEP}"
		unset STEP
	fi

	local -r CACHE_NAME=$1
	# no arg callback
	local -r BUILDAH_HASH_CALLBACK=$2
	# arg1=working container name [must create container this name]
	local -r BUILDAH_BUILD_CALLBACK=$3

	local -i DONE_STAGE WORK_STAGE
	buildah_cache_increament_count "${CACHE_NAME}" "${_STITLE}"
	readonly DONE_STAGE WORK_STAGE

	info "[${CACHE_NAME}] STEP ${WORK_STAGE}: \e[0;38;5;11m${_STITLE}"

	local PREV_STAGE_IMAGE_ID STEP_RESULT_IMAGE PREV_STEP_IMAGE
	PREV_STEP_IMAGE=$(cache_create_name "${CACHE_NAME}" "${DONE_STAGE}")
	STEP_RESULT_IMAGE=$(cache_create_name "${CACHE_NAME}" "${WORK_STAGE}")
	PREV_STAGE_IMAGE_ID=$(get_last_image_id)
	readonly PREV_STAGE_IMAGE_ID STEP_RESULT_IMAGE PREV_STEP_IMAGE

	if skip_this_step "${CACHE_NAME}"; then
		record_last_image -f "${STEP_RESULT_IMAGE}"
		commit_step_section "${CACHE_NAME}" "${_STITLE}" "${PREV_STEP_IMAGE}" "${STEP_RESULT_IMAGE}"
		return
	fi

	if [[ ${DONE_STAGE} -gt 0 ]]; then
		if ! image_exists "${PREV_STEP_IMAGE}"; then
			cache_try_pull "${CACHE_NAME}" "${DONE_STAGE}"

			if ! image_exists "${PREV_STEP_IMAGE}"; then
				info_error "required previous stage [${PREV_STEP_IMAGE}] did not exists"
				return 1
			fi
		fi
		local -r PREVIOUS_ID=$(image_get_long_id "${PREV_STEP_IMAGE}" || true)
		if [[ -z ${PREVIOUS_ID} ]]; then
			info_error "failed get id from image (${PREV_STEP_IMAGE}) cache state is invalid."
			return 1
		fi
	else
		local -r PREVIOUS_ID="none"
	fi
	cache_try_pull "${CACHE_NAME}" "${WORK_STAGE}"

	local -r HASH_TMP="${TMPDIR}/cache.hash.input.step${WORK_STAGE}.dat"

	indent
	{
		printf "last image: %q" "${PREV_STAGE_IMAGE_ID}"
		"${BUILDAH_HASH_CALLBACK}"
	} >"${HASH_TMP}"

	local WANTED_HASH
	WANTED_HASH=$(hash_string "${HASH_TMP}")

	info_note "current hash: ${WANTED_HASH}"
	dedent

	if [[ ${BUILDAH_FORCE-no} == "yes" ]]; then
		info_warn "cache skip <BUILDAH_FORCE=yes> target=${WANTED_HASH}"
	elif image_exists "${STEP_RESULT_IMAGE}"; then
		local EXISTS_PREVIOUS_ID EXISTS_HASH
		EXISTS_PREVIOUS_ID="$(image_get_annotation "${STEP_RESULT_IMAGE}" "${ANNOID_CACHE_PREV_STAGE}")"
		EXISTS_HASH="$(image_get_annotation "${STEP_RESULT_IMAGE}" "${ANNOID_CACHE_HASH}")"
		readonly EXISTS_PREVIOUS_ID EXISTS_HASH
		# info_log "EXISTS_HASH=$EXISTS_HASH EXISTS_PREVIOUS_ID=$EXISTS_PREVIOUS_ID"

		if [[ -z ${EXISTS_PREVIOUS_ID} ]] || [[ -z ${EXISTS_HASH} ]]; then
			info_warn "cache state is invalid!"
		else
			info_success "cache exists <hash=${EXISTS_HASH}, base=${EXISTS_PREVIOUS_ID}>"
			if [[ "${EXISTS_HASH}++${EXISTS_PREVIOUS_ID}" == "${WANTED_HASH}++${PREVIOUS_ID}" ]]; then
				_buildah_cache_done "${STEP_RESULT_IMAGE}"
				return
			fi
			info "cache outdat <want=${WANTED_HASH}, base=${PREVIOUS_ID}>"
		fi
	else
		info_success "cache missing: no image: ${STEP_RESULT_IMAGE}"
	fi

	indent
	LAST_CACHE_COMES_FROM=build
	local -r CONTAINER_ID="${CACHE_NAME}_from${DONE_STAGE}_to${WORK_STAGE}"
	new_container "${CONTAINER_ID}" "${PREV_STAGE_IMAGE_ID}" >/dev/null
	try "${BUILDAH_BUILD_CALLBACK}" "${CONTAINER_ID}"
	if [[ $ERRNO -ne 0 ]]; then
		info_error "build callback '${BUILDAH_BUILD_CALLBACK}' failed to run with $ERRNO ($ERRLOCATION)"
		dedent
		return 1
	fi
	info_note "build callback '${BUILDAH_BUILD_CALLBACK}' finish"
	dedent

	local COMMENT="${CACHE_NAME} layer <${DONE_STAGE}> to <${WORK_STAGE}>"
	buildah config \
		"--annotation=${ANNOID_CACHE_HASH}=${WANTED_HASH}" \
		"--annotation=${ANNOID_CACHE_PREV_STAGE}=${PREVIOUS_ID}" \
		"--author=${AUTHOR}" \
		"--comment=cache:step${WORK_STAGE}" \
		"--created-by=RUN build-script # ${COMMENT}" \
		"${CONTAINER_ID}" >/dev/null

	local BUILT_ID
	BUILT_ID=$(buildah commit "${CONTAINER_ID}" "${STEP_RESULT_IMAGE}")

	_buildah_cache_done "${BUILT_ID}"
}

_buildah_cache_done() {
	local -r BUILT_ID=$1
	record_last_image "${BUILT_ID}"

	cache_push "${CACHE_NAME}" "${WORK_STAGE}"
	if [[ -n ${_STITLE} ]]; then
		info_note "[${CACHE_NAME}] STEP ${WORK_STAGE} (\e[0;38;5;13m${_STITLE}\e[0;2m) DONE | result: ${BUILT_ID}\n"
	else
		info_note "[${CACHE_NAME}] STEP ${WORK_STAGE} DONE | result: ${BUILT_ID}\n"
	fi

	if should_quit_after_this_step; then
		info_success "build step done (skip all remaining steps)"
		exit 0
	fi
}