#!/usr/bin/env bash

if [[ -z ${CONFIG_FILE-} ]]; then
	CONFIG_FILE=/opt/nginx.conf
fi

echo "NGINX_CONFIG_SOURCE=${CONFIG_FILE}" >>/etc/environment
echo "PROJECT_NAME=${PP}" >>/etc/environment

systemctl enable nginx-attach.service
