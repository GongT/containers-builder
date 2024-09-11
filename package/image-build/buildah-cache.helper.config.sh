#!/usr/bin/env bash

function buildah_config() {
	local NAME=$1 ARGS
	if [[ -f $2 ]]; then
		mapfile -t ARGS <"$2"
	else
		shift
		ARGS=("$@")
	fi

	__buildah_config_hash() {
		echo "${ARGS[*]}"
	}
	__buildah_config_do() {
		buildah config "${ARGS[@]}" "$1"
	}
	buildah_cache2 "${NAME}" __buildah_config_hash __buildah_config_do
}

function buildah_finalize_image() {
	local NAME=$1 IMAGE_OUT=$2 RESULT

	local -i DONE_STAGE WORK_STAGE
	buildah_cache_increament_count "${NAME}"
	info "[${NAME}] STEP ${WORK_STAGE}: \e[0mFinalize"

	RESULT=$(create_if_not "${NAME}" "${BUILDAH_LAST_IMAGE}")
	buildah commit "${RESULT}" "${IMAGE_OUT}" >/dev/null

	register_exit_handler info_success "success build image\n  - IMAGE = ${LAST_COMMITED_IMAGE}\n  - NAME = ${IMAGE_OUT}\n$(xpodman image history "${LAST_COMMITED_IMAGE}" || true)"
}
