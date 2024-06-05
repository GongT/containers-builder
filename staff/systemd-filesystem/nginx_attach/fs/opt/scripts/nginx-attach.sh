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
	local CFG_FNAME="/run/nginx/vhost.d/${PROJECT}.conf"
	if [[ $1 -eq 0 ]]; then
		rm -v "${CFG_FNAME}"
	else
		cp -v "$NGINX_CONFIG" "${CFG_FNAME}"
	fi
	if command -v curl &>/dev/null; then
		curl --unix-socket /run/sockets/nginx.reload.sock http://_/
	elif command -v nc &>/dev/null; then
		make_http | nc -U /run/sockets/nginx.reload.sock
	elif command -v socat &>/dev/null; then
		make_http | socat - UNIX-CONNECT:/run/sockets/nginx.reload.sock
	else
		echo "no supported communication tool" >&2
	fi
}

if ! [[ -d /run/nginx/vhost.d/ ]]; then
	echo "missing mount folder: /run/nginx/vhost.d/" >&2
	exit 66
fi

if ! [[ -e $NGINX_CONFIG ]]; then
	echo "missing NGINX_CONFIG: $NGINX_CONFIG" >&2
	exit 66
fi

apply_gateway "$1" || {
	apply_gateway "0"
	exit 1
}
