#!/usr/bin/env bash

set -Eeuo pipefail

if [[ ${nginx_config+found} != found ]]; then
	nginx_config=/opt/nginx.conf
fi

mkdir -p /etc/systemd/system/nginx-attach.service.d/
cat <<EOF >/etc/systemd/system/nginx-attach.service.d/path-config.conf
[Service]
Environment=NGINX_CONFIG=$nginx_config
Environment=PROJECT=$PROJECT
EOF

if ! command -v curl &>/dev/null; then
	echo "[nginx-attach] missing curl"
	exit 1
fi

systemctl enable nginx-attach.service
