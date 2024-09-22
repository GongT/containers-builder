#!/usr/bin/env bash

set -u

# note: NGINX_CONFIG_SOURCE is env var, CONFIG_SOURCE is build argument

if [[ ! -e ${NGINX_CONFIG_SOURCE} ]]; then
	echo "missing nginx_attach CONFIG_FILE: ${NGINX_CONFIG_SOURCE}"
	exit 233
fi
if ! mountpoint /run/nginx; then
	echo "missing mounted nginx config folder: /run/nginx"
	exit 233
fi

declare -r CROOT_DIR="/run/nginx/contribute"
declare -r MASTER_CONTROL_DIR="${CROOT_DIR}/.master"
declare -r CONF_DIR="${CROOT_DIR}/${CONTAINER_ID}"
declare -r CONTROL_DIR="${CONF_DIR}/.control"

if [[ $* == 'create' ]]; then
	echo "write config files into: ${CONF_DIR}"
	if [[ -f ${NGINX_CONFIG_SOURCE} ]]; then
		mkdir -p "${CONF_DIR}/vhost.d"
		cp "${NGINX_CONFIG_SOURCE}" "${CONF_DIR}/vhost.d/${CONTAINER_ID}.conf"
	elif [[ -d ${NGINX_CONFIG_SOURCE} ]]; then
		mkdir -p "${CONF_DIR}"
		cp -r "${NGINX_CONFIG_SOURCE}/." "${CONF_DIR}"
	else
		echo "invalid type must be file or folder: ${NGINX_CONFIG_SOURCE}"
		exit 233
	fi

	mkdir -p "${CONTROL_DIR}"
	echo "pending" >"${CONTROL_DIR}/state"
else
	echo "delete configs from: ${CONF_DIR}"
	mkdir -p "${CONTROL_DIR}"
	echo "delete" >"${CONTROL_DIR}/state"
fi

echo "notify async nginx reload..."
mkdir -p "${MASTER_CONTROL_DIR}/requests"
mkfifo --mode=0777 "${MASTER_CONTROL_DIR}/requests/${CONTAINER_ID}.fifo"
(
	cat "${MASTER_CONTROL_DIR}/requests/${CONTAINER_ID}.fifo" | grep success
) &
wait $!
RET=$?
echo "notify return ${RET}"

exit ${RET}
