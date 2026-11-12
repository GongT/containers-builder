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
	buildah_cache_increament_count "${NAME}" "最终配置步骤"
	info "[${NAME}] 步骤 ${WORK_STAGE}: \e[0m最终配置"

	if skip_this_step "${NAME}"; then
		commit_step_section "${NAME}" "Finalize" "${IMAGE}" "${IMAGE_OUT}"
		return
	fi

	RESULT=$(create_if_not "${NAME}" "${IMAGE}")

	buildah run "$RESULT" /usr/bin/sh -c "rm -rf /tmp/* /var/log/* /var/cache/*"
	buildah commit "${RESULT}" "${IMAGE_OUT}" >/dev/null

	local SUMMARY
	SUMMARY=$(
		echo "## 成功构建镜像"
		echo " - IMAGE = ${LAST_COMMITED_IMAGE}"
		echo " - NAME = ${IMAGE_OUT}"
		echo " - BASE = ${BASE_IMAGE_NAME-}"
		echo ""
		echo '```text'
		xpodman image tree "${LAST_COMMITED_IMAGE}"
		echo '```'
		echo ""
	)

	control_ci summary "${SUMMARY}"
}
