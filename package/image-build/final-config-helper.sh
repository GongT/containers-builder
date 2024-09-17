#!/usr/bin/env bash

function buildah_config() {
	local NAME=$1 ARGS
	if [[ -f $2 ]]; then
		mapfile -t ARGS <"$2"
	else
		shift
		ARGS=("$@")
	fi

	if [[ -z ${STEP-} ]]; then
		STEP="配置容器"
	fi
	__buildah_config_hash() {
		echo "${ARGS[*]}"
	}
	__buildah_config_do() {
		buildah config "${ARGS[@]}" "$1"
	}
	buildah_cache "${NAME}" __buildah_config_hash __buildah_config_do
}

function buildah_finalize_image() {
	local NAME=$1 IMAGE_OUT=$2 RESULT IMAGE

	IMAGE=$(get_last_image_id)

	local -i DONE_STAGE WORK_STAGE
	buildah_cache_increament_count "${NAME}" "Finalize"
	info "[${NAME}] STEP ${WORK_STAGE}: \e[0mFinalize"

	if skip_this_step "${NAME}"; then
		commit_step_section "${NAME}" "Finalize" "${IMAGE}" "${IMAGE_OUT}"
		return
	fi

	RESULT=$(create_if_not "${NAME}" "${IMAGE}")

	buildah commit "${RESULT}" "${IMAGE_OUT}" >/dev/null

	local SUMMARY
	SUMMARY=$(
		echo "success build image"
		echo "  - IMAGE = $LAST_COMMITED_IMAGE"
		echo "  - NAME = $IMAGE_OUT"
		echo "  - BASE = ${LAST_KNOWN_BASE-}"
		xpodman image tree "$LAST_COMMITED_IMAGE"
	)

	control_ci summary "${SUMMARY}"
}
