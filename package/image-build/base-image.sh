declare LAST_KNOWN_BASE=
function buildah_cache_start() {
	local BASE_IMG=$1
	local RESULT_ID BASE_NAME
	LAST_CACHE_COMES_FROM=never

	if [[ ${BASE_IMG} == "fedora"* || ${BASE_IMG} == "fedora-minimal"* ]]; then
		BASE_IMG="quay.io/fedora/${BASE_IMG}"
	fi
	if [[ ${BASE_IMG} == "quay.io/fedora/fedora" || ${BASE_IMG} == "quay.io/fedora/fedora-minimal" ]]; then
		BASE_IMG+=":${FEDORA_VERSION}"
	fi
	if [[ ${BASE_IMG} != *":"* ]]; then
		BASE_IMG+=":latest"
	fi

	info_success "\n缓存分支开始"
	if [[ ${BASE_IMG} == scratch ]]; then
		LAST_KNOWN_BASE=
		info_note "  - 使用空基础镜像 (scratch)"
		record_last_image "scratch"
		return
	fi

	if is_recording_steps; then
		info "  - 假的 (因正在记录中而跳过)"
		record_last_image scratch

		record_last_base_name "${BASE_IMG}"
		BASE_NAME=fake
		return
	fi

	RESULT_ID=$(image_find_digist "${BASE_IMG}")
	if [[ -n ${RESULT_ID} ]]; then
		if is_ci; then
			if [[ ${NO_PULL_BASE-} == yes ]]; then
				info_warn "  - 跳过拉取基础镜像，因为 NO_PULL_BASE=${NO_PULL_BASE-}"
			else
				control_ci group "[缓存分支开始] 拉取基础镜像: ${BASE_IMG}"
				xpodman image pull "${BASE_IMG}"
				control_ci groupEnd
			fi
		fi

		info_note "  - 使用传入的完整名称: ${BASE_NAME}"
	else
		info_note "  - 基础镜像不存在，拉取: ${BASE_IMG}"
		RESULT_ID=$(xpodman image pull "${BASE_IMG}")
	fi

	record_last_image "${RESULT_ID}"

	BASE_NAME=$(image_find_full_name "${RESULT_ID}")
	record_last_base_name "${BASE_NAME}"
	info_note "  - 完整名称: ${BASE_NAME}"
}
