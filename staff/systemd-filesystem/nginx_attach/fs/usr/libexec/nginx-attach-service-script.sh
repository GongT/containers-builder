#!/usr/bin/env bash

set -Eeuo pipefail

# note: NGINX_CONFIG_SOURCE is env var, CONFIG_SOURCE is build argument

declare -r NGINX_UPLOAD_SCRIPT="${SHARED_SOCKET_PATH-}/.nginx.upload.sh"

echo "$1 nginx:"
echo "    container id: ${CONTAINER_ID-}"
echo "    package: ${NGINX_CONFIG_PACKAGE-}"
echo "    control script: ${NGINX_UPLOAD_SCRIPT}"

if [[ $1 == attach ]]; then
	if [[ -n ${IN_DEBUG_MODE-} ]]; then
		echo "in debug mode, fail to run."
		exit 233
	fi

	if [[ ! -e ${NGINX_CONFIG_PACKAGE} ]]; then
		echo "missing compressed nginx config file."
		exit 66
	fi

	declare -i I=0
	while ! [[ -e ${NGINX_UPLOAD_SCRIPT} ]]; do
		if [[ $((I % 10)) -eq 0 ]]; then
			echo "waiting uploader script to exists..."
		fi

		sleep 1
		I+=1
	done

	exec bash "${NGINX_UPLOAD_SCRIPT}" "${CONTAINER_ID}" "${NGINX_CONFIG_PACKAGE}"
else
	echo "Not Impl"
	exit 1
fi
