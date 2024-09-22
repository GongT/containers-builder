#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -e ${NGINX_CONFIG_SOURCE} ]]; then
	echo "missing nginx_attach CONFIG_FILE: ${NGINX_CONFIG_SOURCE}"
	exit 1
fi
if ! mountpoint "${SHARED_SOCKET_PATH}"; then
	echo "missing mounted socket folder: ${SHARED_SOCKET_PATH}"
	exit 1
fi

declare -r CONF_DIR="/tmp/nginx-package"
if [[ -f ${NGINX_CONFIG_SOURCE} ]]; then
	mkdir -p "${CONF_DIR}/vhost.d"
	cp "${NGINX_CONFIG_SOURCE}" "${CONF_DIR}/vhost.d/${CONTAINER_ID}.conf"
elif [[ -d ${NGINX_CONFIG_SOURCE} ]]; then
	mkdir -p "${CONF_DIR}"
	cp -r "${NGINX_CONFIG_SOURCE}/." "${CONF_DIR}"
else
	echo "invalid type must be file or folder: ${NGINX_CONFIG_SOURCE}"
	exit 1
fi

cd "${CONF_DIR}"
tar -c -f "${NGINX_CONFIG_PACKAGE}" .

echo "config files content:"
tar -t -f "${NGINX_CONFIG_PACKAGE}"
