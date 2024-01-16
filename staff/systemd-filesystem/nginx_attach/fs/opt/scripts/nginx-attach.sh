#!/usr/bin/env bash

set -Eeuo pipefail

apply_gateway() {
	local CFG_FNAME="/run/nginx/vhost.d/${PROJECT}.conf"
	if [[ $1 -eq 0 ]]; then
		rm -v "${CFG_FNAME}"
	else
		cp -v "$NGINX_CONFIG" "${CFG_FNAME}"
	fi
	curl --unix /run/sockets/nginx.reload.sock http://_/ || true
}

if ! [[ -d /run/nginx/vhost.d/ ]]; then
	echo "missing mount folder: /run/nginx/vhost.d/" >&2
	exit 66
fi

if ! [[ -e $NGINX_CONFIG ]]; then
	echo "missing NGINX_CONFIG: $NGINX_CONFIG" >&2
	exit 66
fi

apply_gateway "$1"
