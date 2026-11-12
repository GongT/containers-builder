#!/usr/bin/env bash

set -Eeuo pipefail

function die() {
	local code="$1"
	shift
	echo "$*" >&2
	exit "$code"
}

if [[ -z ${SHARED_SOCKET_PATH-} || -z ${NGINX_CONFIG_PACKAGE-}   ]]; then
	die 233 "缺少必要的环境变量!!!"
fi

declare -r NGINX_UPLOAD_SCRIPT="${SHARED_SOCKET_PATH-}/.nginx.upload.sh"

echo "操作nginx网关 [$1]:" >&2
echo "    容器ID: ${CONTAINER_ID-}" >&2
echo "    配置包: ${NGINX_CONFIG_PACKAGE-}" >&2
echo "    控制脚本: ${NGINX_UPLOAD_SCRIPT}" >&2

if [[ $1 == attach ]]; then
	if [[ -n ${IN_DEBUG_MODE-} ]]; then
		die 0 "调试模式下，拒绝执行并成功退出。"
	fi

	# 等待从网关容器挂载过来的目录中出现上传脚本
	declare -i I=0
	while ! [[ -e ${NGINX_UPLOAD_SCRIPT} ]]; do
		if [[ $((I % 10)) -eq 0 ]]; then
			echo "等待网关服务上传脚本存在..."
		fi

		sleep 1
		I+=1
	done

	bash "${NGINX_UPLOAD_SCRIPT}" "${CONTAINER_ID}" "${NGINX_CONFIG_PACKAGE}"

	rm -f "${NGINX_CONFIG_PACKAGE}"
else
	die 1 "未实现"
fi
