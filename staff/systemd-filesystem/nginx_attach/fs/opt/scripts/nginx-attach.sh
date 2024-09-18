#!/usr/bin/env bash

set -u

make_http() {
	echo 'GET / HTTP/1.1
Host: 127.0.0.1:12345
User-Agent: curl/8.6.0
Accept: */*

'
}

apply_gateway() {
	local CFG_FNAME="/run/nginx/config/vhost.d/${PROJECT}.conf"
	if [[ $1 -eq 0 ]]; then
		echo "remove config file: $CFG_FNAME"
		rm -v "${CFG_FNAME}"
	else
		echo "copy config file: $NGINX_CONFIG (to $CFG_FNAME)"
		cp -v "$NGINX_CONFIG" "${CFG_FNAME}"
	fi
	if command -v curl &>/dev/null; then
		echo "notify using curl"
		curl --unix-socket /run/sockets/nginx.reload.sock http://_/
	elif command -v nc &>/dev/null; then
		echo "notify using nc"
		make_http | nc -U /run/sockets/nginx.reload.sock
	elif command -v socat &>/dev/null; then
		echo "notify using socat"
		make_http | socat - UNIX-CONNECT:/run/sockets/nginx.reload.sock
	else
		echo "no supported communication tool" >&2
		return 1
	fi
}

if [[ ! -d /run/nginx/config/vhost.d/ ]]; then
	echo "missing mount folder: /run/nginx/config/vhost.d/" >&2
	exit 66
fi

if [[ ! -e $NGINX_CONFIG ]]; then
	echo "missing NGINX_CONFIG: $NGINX_CONFIG" >&2
	exit 66
fi

apply_gateway "$1" || {
	apply_gateway "0" || true
	exit 1
}
