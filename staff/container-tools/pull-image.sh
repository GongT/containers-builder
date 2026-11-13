#!/usr/bin/env bash

source "../../package/include.sh"

if [[ $# -ne 1 ]]; then
	die "使用方法: $0 <missing|always>"
fi
declare -r PULL_POLICY=$1

if [[ -z ${PODMAN_IMAGE_NAME} ]]; then
	die "缺失环境变量: PODMAN_IMAGE_NAME"
fi

info "使用策略'${PULL_POLICY}'拉取镜像'${PODMAN_IMAGE_NAME}'"

OLD_ID=$(image_find_digits "${PODMAN_IMAGE_NAME}")
if [[ ${PULL_POLICY} != "always" && -n ${OLD_ID} ]]; then
	info_success "完成, 已存在: ${OLD_ID}"
	exit 0
fi

LAST_PULL_DIR="${PRIVATE_CACHE}/last-pull"
mkdir -p "${LAST_PULL_DIR}"
STORE_FILE="${LAST_PULL_DIR}/$(echo "${PODMAN_IMAGE_NAME}" | sed -E 's#[./-:]#_#g' | sed -E 's#__+#_#g')"
declare -i NOW LAST

NOW=$(date +%s)
if [[ -n ${OLD_ID} && -e ${STORE_FILE} ]]; then
	if [[ ${FORCE_PULL-} == 'yes' ]]; then
		info_warn "输入参数指定需要强制拉取"
	else
		LAST=$(<"${STORE_FILE}")
		LASTSTR=$(TZ=CST date --date="@${LAST}" "+%F %T")
		if [[ ${NOW} -lt $((LAST + 3600)) ]]; then
			info_success "完成: ${OLD_ID} @${LASTSTR}"
			exit 0
		else
			info_note "状态过期: ${OLD_ID} @${LASTSTR}"
		fi
	fi
else
	info_note "首次拉取."
fi

unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

info_log "从镜像仓库拉取..."

declare -i TRIES=1 MAX_TRY=5
while true; do
	sdnotify "--status=[${TRIES}/${MAX_TRY}] 正在准备镜像" "EXTEND_TIMEOUT_USEC=$((30 * 1000000))"
	if podman image pull --retry 1 "${PODMAN_IMAGE_NAME}"; then
		break
	fi

	TRIES+=1
	if [[ ${TRIES} -gt ${MAX_TRY} ]]; then
		sdnotify --stopping "--status=镜像下载失败"
		info_note "拉取失败, 尝试 ${MAX_TRY} 次后终止."
		exit 1
	fi

	sleep 3s
done

NEW_ID=$(image_find_digits "${PODMAN_IMAGE_NAME}")

if [[ ${OLD_ID} == "${NEW_ID}" ]]; then
	info_success "镜像已是最新: ${OLD_ID}"
else
	info_success "下载了更新的镜像: ${NEW_ID}"
fi
printf '%s' "${NOW}" >"${STORE_FILE}"

if [[ ${SKIP_REMOVE+found} != found ]]; then
	info_note "移除未使用的镜像:"
	podman images \
		| grep --fixed-strings '<none>' \
		| awk '{print $3}' \
		| while read -r IMAGE_ID; do
			sdnotify "--status=删除镜像 ${IMAGE_ID}" "EXTEND_TIMEOUT_USEC=$((30 * 1000000))"
			podman image rm "${IMAGE_ID}" || true
		done
fi

sdnotify "--status=镜像就绪" "EXTEND_TIMEOUT_USEC=$((10 * 1000000))"
