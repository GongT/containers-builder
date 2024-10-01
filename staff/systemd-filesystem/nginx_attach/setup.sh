#!/usr/bin/env bash

if [[ -z ${CONFIG_FILE-} ]]; then
	if [[ -f /opt/nginx.conf ]]; then
		CONFIG_FILE=/opt/nginx.conf
	elif [[ -d /opt/nginx ]]; then
		CONFIG_FILE=/opt/nginx
	else
		die "can not found '/opt/nginx' or '/opt/nginx.conf', set CONFIG_FILE if it has another name."
	fi
fi

if [[ ! -e ${CONFIG_FILE} ]]; then
	die "missing nginx config file: ${CONFIG_FILE}"
fi

exportenv "NGINX_CONFIG_SOURCE" "${CONFIG_FILE}"

systemctl enable nginx-attach.service
