#!/usr/bin/env bash

declare -A _CURRENT_STAGE_STORE=()
declare LAST_CACHE_COMES_FROM
if [[ -z ${LAST_CACHE_COMES_FROM-} ]]; then
	LAST_CACHE_COMES_FROM=never
fi

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
# hash_function <BASE_IMAGE_ID>
# build_function <CONTAINER_NAME>
function buildah_cache() {
	local _STITLE=""
	if [[ ${STEP+found} == found ]]; then
		_STITLE="${STEP}"
		unset STEP
	fi

	local -r START_TIME=$(uptime_sec)

	local -r CACHE_NAME=$1
	# no arg callback
	local -r BUILDAH_HASH_CALLBACK=$2
	# arg1=working container name [must create container this name]
	local -r BUILDAH_BUILD_CALLBACK=$3

	local -i DONE_STAGE WORK_STAGE
	buildah_cache_increament_count "${CACHE_NAME}" "${_STITLE}"
	readonly DONE_STAGE WORK_STAGE

	info "[${CACHE_NAME}] 步骤 ${WORK_STAGE}: \e[0;38;5;11m${_STITLE}"

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
				info_error "需要的前一步阶段 [${PREV_STEP_IMAGE}] 不存在"
				return 1
			fi
		fi
		local -r PREVIOUS_ID=$(image_get_long_id "${PREV_STEP_IMAGE}" || true)
		if [[ -z ${PREVIOUS_ID} ]]; then
			info_error "从镜像 (${PREV_STEP_IMAGE}) 获取 ID 失败，缓存状态无效。"
			return 1
		fi
	else
		local -r PREVIOUS_ID="none"
	fi
	cache_try_pull "${CACHE_NAME}" "${WORK_STAGE}"

	local -r HASH_TMP="${TMPDIR}/cache.hash.input.step${WORK_STAGE}.dat"

	indent
	{
		printf "last-image-id: %q" "${PREV_STAGE_IMAGE_ID}"
		"${BUILDAH_HASH_CALLBACK}" "${PREV_STAGE_IMAGE_ID}"
	} >"${HASH_TMP}"

	local WANTED_HASH
	WANTED_HASH=$(hash_string "${HASH_TMP}")

	info_note "当前步骤hash: ${WANTED_HASH}"
	dedent

	if [[ ${BUILDAH_FORCE-no} == "yes" ]]; then
		info_warn "缓存: 跳过 <BUILDAH_FORCE=yes> 目标=${WANTED_HASH}"
	elif image_exists "${STEP_RESULT_IMAGE}"; then
		local EXISTS_PREVIOUS_ID EXISTS_HASH
		EXISTS_PREVIOUS_ID="$(image_get_annotation "${STEP_RESULT_IMAGE}" "${ANNOID_CACHE_PREV_STAGE}")"
		EXISTS_HASH="$(image_get_annotation "${STEP_RESULT_IMAGE}" "${ANNOID_CACHE_HASH}")"
		readonly EXISTS_PREVIOUS_ID EXISTS_HASH
		# info_log "EXISTS_HASH=$EXISTS_HASH EXISTS_PREVIOUS_ID=$EXISTS_PREVIOUS_ID"

		if [[ -z ${EXISTS_PREVIOUS_ID} ]] || [[ -z ${EXISTS_HASH} ]]; then
			info_error "缓存状态无效!"
		else
			if [[ "${EXISTS_HASH}++${EXISTS_PREVIOUS_ID}" == "${WANTED_HASH}++${PREVIOUS_ID}" ]]; then
				info_success "缓存: 命中 <当前=${EXISTS_HASH}, 基础=${EXISTS_PREVIOUS_ID}>"
				_buildah_cache_done hit "${STEP_RESULT_IMAGE}"
				return
			fi
			info_warn "缓存: 过期 <当前=${EXISTS_HASH}, 期望=${WANTED_HASH}, 基础=${PREVIOUS_ID}>"
		fi
	else
		info_warn "缓存: 缺失 <无此镜像: ${STEP_RESULT_IMAGE}>"
	fi

	indent
	LAST_CACHE_COMES_FROM=build
	local -r CID="${CACHE_NAME}_from${DONE_STAGE}_to${WORK_STAGE}"
	new_container "${CID}" "${PREV_STAGE_IMAGE_ID}" >/dev/null
	try "${BUILDAH_BUILD_CALLBACK}" "${CID}"
	if [[ $ERRNO -ne 0 ]]; then
		info_error "构建回调 '${BUILDAH_BUILD_CALLBACK}' 执行失败，错误码 $ERRNO @ $ERRLOCATION"
		dedent
		return 1
	fi
	info_note "构建回调 '${BUILDAH_BUILD_CALLBACK}' 完成"
	dedent

	local COMMENT="${CACHE_NAME} 基于层 <${DONE_STAGE}> 构建出 <${WORK_STAGE}>"
	buildah config \
		"--annotation=${ANNOID_CACHE_HASH}=${WANTED_HASH}" \
		"--annotation=${ANNOID_CACHE_PREV_STAGE}=${PREVIOUS_ID}" \
		"--author=${AUTHOR}" \
		"--created-by=RUN build-script # ${COMMENT}" \
		"${CID}" >/dev/null

	local BUILT_ID
	BUILT_ID=$(buildah commit "${CID}" "${STEP_RESULT_IMAGE}")

	_buildah_cache_done miss "${BUILT_ID}"
}

_buildah_cache_done() {
	local -r CACHE_STATE=$1 BUILT_ID=$2
	record_last_image "${BUILT_ID}"

	cache_push "${CACHE_NAME}" "${WORK_STAGE}"
	if [[ -n ${_STITLE} ]]; then
		info_note "[${CACHE_NAME}] 步骤 ${WORK_STAGE} (\e[0;38;5;13m${_STITLE}\e[0;2m) 完成 | 结果ID: ${BUILT_ID}\n"
	else
		info_note "[${CACHE_NAME}] 步骤 ${WORK_STAGE} 完成 | 结果ID: ${BUILT_ID}\n"
	fi

	local -r END_TIME=$(uptime_sec)

	SUMMARY=$(
		echo "## ${CACHE_NAME} 步骤 ${WORK_STAGE} - ${_STITLE}"
		echo ""
		echo " - 缓存命中状态: ${CACHE_STATE}"
		echo " - 缓存 hash: ${WANTED_HASH}"
		echo " - 用时: $(seconds_timespan $((END_TIME - START_TIME)))"
		echo ""
		echo "<details>"
		echo "<summary><h5>基础镜像信息</h5></summary>"
		echo ""
		echo ""
		_image_summary "${PREV_STAGE_IMAGE_ID}"
		echo ""
		echo "</details>"
		echo ""
		echo "#### 构建结果"
		_image_summary "${BUILT_ID}"
		echo ""
	)
	control_ci summary "${SUMMARY}"

	if should_quit_after_this_step; then
		info_success "构建步骤完成 (跳过所有剩余步骤)"
		exit 0
	fi
}

function _image_summary() {
	local -r ID=$1
	if [[ ${ID} == none ]]; then
		echo " - 空镜像 (scratch)"
		return
	fi

	local JSON CTIME SIZE NAME
	JSON=$(podman image history --format=json "${ID}")

	CTIME=$(parse_json "${JSON}" ".[0].created")
	SIZE=$(parse_json "${JSON}" ".[0].size")
	NAME=$(parse_json "${JSON}" ".[0].tags[0]" || echo "no name")

	printf ' - 创建时间: %s\n' "$(TZ=GMT+8 systemd-analyze timestamp "${CTIME}" | grep -E 'Normalized form:|From now:' | sed -E 's/^.+:\s+//' | tr '\n' '`' | sed 's/`/ (`/'))"
	printf ' - 大小: %s\n' "$(numfmt --to=iec --suffix=B --format="%.2f" "${SIZE}")"
	printf ' - 名称: %s\n' "${NAME}"
}
