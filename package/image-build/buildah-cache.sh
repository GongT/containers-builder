#!/usr/bin/env bash

declare -A _CURRENT_STAGE_STORE=()
declare LAST_CACHE_COMES_FROM=build # or pull

function buildah_cache_increament_count() {
	local NAME=$1
	if [[ ${_CURRENT_STAGE_STORE[${NAME}]+found} == 'found' ]]; then
		DONE_STAGE="${_CURRENT_STAGE_STORE[${NAME}]}"
		WORK_STAGE="${DONE_STAGE} + 1"
	else
		DONE_STAGE=0
		WORK_STAGE=1
	fi
}

# buildah_cache "$PREVIOUS_ID" hash_function build_function
# build_function <RESULT_CONTAINER_NAME>
function buildah_cache() {
	local _STITLE=""
	if [[ ${STEP+found} == found ]]; then
		_STITLE="${STEP}"
		unset STEP
	fi

	local -r BUILDAH_NAME_BASE=$1
	# no arg callback
	local -r BUILDAH_HASH_CALLBACK=$2
	# arg1=working container name [must create container this name]
	local -r BUILDAH_BUILD_CALLBACK=$3

	local STEP_RESULT_IMAGE PREV_STEP_IMAGE

	local -i DONE_STAGE WORK_STAGE
	buildah_cache_increament_count "${BUILDAH_NAME_BASE}"
	_CURRENT_STAGE_STORE[${BUILDAH_NAME_BASE}]="${WORK_STAGE}"

	info "[${BUILDAH_NAME_BASE}] STEP ${WORK_STAGE}: \e[0;38;5;11m${_STITLE}"
	indent

	PREV_STEP_IMAGE=$(cache_create_name "${BUILDAH_NAME_BASE}" "${DONE_STAGE}")
	STEP_RESULT_IMAGE=$(cache_create_name "${BUILDAH_NAME_BASE}" "${WORK_STAGE}")

	if [[ ${DONE_STAGE} -gt 0 ]]; then
		if ! image_exists "${PREV_STEP_IMAGE}"; then
			die "required previous stage [${PREV_STEP_IMAGE}] did not exists"
		fi
		local -r PREVIOUS_ID=$(image_get_long_id "${PREV_STEP_IMAGE}" || true)
		if [[ -z ${PREVIOUS_ID} ]]; then
			die "failed get id from image (${PREV_STEP_IMAGE}) cache state is invalid."
		fi
	else
		local -r PREVIOUS_ID="none"
	fi

	cache_try_pull "${BUILDAH_NAME_BASE}" "${WORK_STAGE}"

	local WANTED_HASH HASH_TMP="${TMPDIR}/cache.hash.input.step${WORK_STAGE}.dat"
	"${BUILDAH_HASH_CALLBACK}" >"${HASH_TMP}"
	WANTED_HASH=$(md5sum "${HASH_TMP}" | awk '{print $1}')

	if [[ ${BUILDAH_FORCE-no} == "yes" ]]; then
		info_warn "cache skip <BUILDAH_FORCE=yes> target=${WANTED_HASH}"
	elif image_exists "${STEP_RESULT_IMAGE}"; then
		local EXISTS_PREVIOUS_ID
		EXISTS_PREVIOUS_ID="$(image_get_annotation "${STEP_RESULT_IMAGE}" "${ANNOID_CACHE_PREV_STAGE}")"
		local EXISTS_HASH
		EXISTS_HASH="$(image_get_annotation "${STEP_RESULT_IMAGE}" "${ANNOID_CACHE_HASH}")"
		# info_log "EXISTS_HASH=$EXISTS_HASH EXISTS_PREVIOUS_ID=$EXISTS_PREVIOUS_ID"

		if [[ -z ${EXISTS_PREVIOUS_ID} ]] || [[ -z ${EXISTS_HASH} ]]; then
			info_warn "cache state is invalid!"
		else
			info_success "cache exists <hash=${EXISTS_HASH}, base=${EXISTS_PREVIOUS_ID}>"
			if [[ "${EXISTS_HASH}++${EXISTS_PREVIOUS_ID}" == "${WANTED_HASH}++${PREVIOUS_ID}" ]]; then
				BUILDAH_LAST_IMAGE=$(image_get_long_id "${STEP_RESULT_IMAGE}")
				_buildah_cache_done
				return
			fi
			info "cache outdat <want=${WANTED_HASH}, base=${PREVIOUS_ID}>"
		fi
	else
		info_success "cache missing: no image: ${STEP_RESULT_IMAGE}"
	fi

	LAST_CACHE_COMES_FROM=build
	local -r CONTAINER_ID="${BUILDAH_NAME_BASE}_from${DONE_STAGE}_to${WORK_STAGE}"
	"${BUILDAH_BUILD_CALLBACK}" "${CONTAINER_ID}"
	info_note "build callback finish"

	if ! container_exists "${CONTAINER_ID}"; then
		die "BUILDAH_BUILD_CALLBACK<${BUILDAH_BUILD_CALLBACK}> did not create ${CONTAINER_ID}."
	fi

	local COMMENT="${BUILDAH_NAME_BASE} layer <${DONE_STAGE}> to <${WORK_STAGE}>"
	buildah config \
		"--annotation=${ANNOID_CACHE_HASH}=${WANTED_HASH}" \
		"--annotation=${ANNOID_CACHE_PREV_STAGE}=${PREVIOUS_ID}" \
		"--author=${AUTHOR}" \
		"--comment=cache:step${WORK_STAGE}" \
		"--created-by=RUN build-script # ${COMMENT}" \
		"${CONTAINER_ID}" >/dev/null

	BUILDAH_LAST_IMAGE=$(buildah commit "${CONTAINER_ID}" "${STEP_RESULT_IMAGE}")

	_buildah_cache_done
}

_buildah_cache_done() {
	cache_push "${BUILDAH_NAME_BASE}" "${WORK_STAGE}"
	dedent
	if [[ -n ${_STITLE} ]]; then
		info_note "[${BUILDAH_NAME_BASE}] STEP ${WORK_STAGE} (\e[0;38;5;13m${_STITLE}\e[0;2m) DONE | BUILDAH_LAST_IMAGE=${BUILDAH_LAST_IMAGE}\n"
	else
		info_note "[${BUILDAH_NAME_BASE}] STEP ${WORK_STAGE} DONE | BUILDAH_LAST_IMAGE=${BUILDAH_LAST_IMAGE}\n"
	fi
}

declare LAST_KNOWN_BASE=
function buildah_cache_start() {
	local BASE_IMG=$1
	info "start cache branch"
	if [[ ${BASE_IMG} == scratch ]]; then
		LAST_KNOWN_BASE=
		info_note "  - using empty base"
		BUILDAH_LAST_IMAGE="scratch"
		return
	fi

	LAST_KNOWN_BASE="${BASE_IMG}"
	if [[ -n ${NO_PULL_BASE-} ]]; then
		info_warn "  - skip pull base due to NO_PULL_BASE=${NO_PULL_BASE} (${BASE_IMG})"
	elif is_ci; then
		control_ci group "[cache start] pull base image: ${BASE_IMG}"
		buildah pull "${BASE_IMG}" >/dev/null
		control_ci groupEnd
	elif BUILDAH_LAST_IMAGE=$(image_find_id "${BASE_IMG}") && [[ -n ${BUILDAH_LAST_IMAGE} ]]; then
		info_note "  - using exists base: ${BASE_IMG}"
	else
		info_note "  - using base not exists, pull it: ${BASE_IMG}"
		buildah pull "${BASE_IMG}" >/dev/null
	fi
}
