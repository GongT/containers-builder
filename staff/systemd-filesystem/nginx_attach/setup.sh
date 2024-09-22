#!/usr/bin/env bash

if [[ -z ${CONFIG_FILE-} ]]; then
	CONFIG_FILE=/opt/nginx.conf
fi

exportenv "NGINX_CONFIG_SOURCE" "${CONFIG_FILE}"

systemctl enable nginx-attach.service
