#!/usr/bin/env bash
set -Eeuo pipefail

function die() {
	echo "$*" >&2
	exit 1
}

if [[ ! -e ${NGINX_CONFIG_SOURCE} ]]; then
	die "缺少 nginx_attach 组件需要的配置文件: ${NGINX_CONFIG_SOURCE}"
fi
if ! mountpoint "${SHARED_SOCKET_PATH}"; then
	die "缺少已挂载的 socket 文件夹: ${SHARED_SOCKET_PATH}"
fi

declare -r CONF_DIR="/tmp/nginx-package"
if [[ -f ${NGINX_CONFIG_SOURCE} ]]; then
	mkdir -p "${CONF_DIR}/vhost.d"
	cp -f "${NGINX_CONFIG_SOURCE}" "${CONF_DIR}/vhost.d/${CONTAINER_ID}.conf"
elif [[ -d ${NGINX_CONFIG_SOURCE} ]]; then
	mkdir -p "${CONF_DIR}"
	cp -rf "${NGINX_CONFIG_SOURCE}/." "${CONF_DIR}"
else
	die "配置文件类型必须是文件或文件夹: ${NGINX_CONFIG_SOURCE}"
fi

cd "${CONF_DIR}"
rm -f "${NGINX_CONFIG_PACKAGE}"
tar -c -f "${NGINX_CONFIG_PACKAGE}" .

echo "配置文件打包内容:"
tar -t -f "${NGINX_CONFIG_PACKAGE}"

echo "打包文件保存到: ${NGINX_CONFIG_PACKAGE}"
