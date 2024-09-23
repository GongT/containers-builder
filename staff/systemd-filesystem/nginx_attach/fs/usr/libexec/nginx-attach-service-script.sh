#!/usr/bin/env bash

set -Eeuo pipefail

# note: NGINX_CONFIG_SOURCE is env var, CONFIG_SOURCE is build argument

declare -r NGINX_UPLOAD_SCRIPT="${SHARED_SOCKET_PATH-}/.nginx.upload.sh"

echo "$1 nginx:" >&2
echo "    container id: ${CONTAINER_ID-}" >&2
echo "    package: ${NGINX_CONFIG_PACKAGE-}" >&2
echo "    control script: ${NGINX_UPLOAD_SCRIPT}" >&2

if [[ -z ${SHARED_SOCKET_PATH-} || -z ${NGINX_CONFIG_PACKAGE-} || -z ${NGINX_UPLOAD_SCRIPT-} ]]; then
	echo "missing required environment!!!" >&2
	exit 233
fi

if [[ $1 == attach ]]; then
	if [[ -n ${IN_DEBUG_MODE-} ]]; then
		echo "in debug mode, fail to run."
		exit 233
	fi
	bash /usr/libexec/nginx-attach-prepare.sh

	declare -i I=0
	while ! [[ -e ${NGINX_UPLOAD_SCRIPT} ]]; do
		if [[ $((I % 10)) -eq 0 ]]; then
			echo "waiting uploader script to exists..."
		fi

		sleep 1
		I+=1
	done

	bash "${NGINX_UPLOAD_SCRIPT}" "${CONTAINER_ID}" "${NGINX_CONFIG_PACKAGE}"

	rm -f "${NGINX_CONFIG_PACKAGE}"
else
	echo "Not Impl"
	exit 1
fi
