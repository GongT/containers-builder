declare -xr ANNOID_CACHE_PREV_STAGE="me.gongt.cache.prevstage"
declare -xr ANNOID_CACHE_HASH="me.gongt.cache.hash"
declare -xr LABELID_RESULT_HASH="me.gongt.result"
declare -xr LABELID_STOP_COMMAND="me.gongt.cmd.stop"
declare -xr LABELID_RELOAD_COMMAND="me.gongt.cmd.reload"
declare -xr LABELID_USE_SYSTEMD="me.gongt.using.systemd"
declare -xr LABELID_USE_NGINX_ATTACH="me.gongt.using.nginx-attach"

declare -xr ANNOID_OPEN_IMAGE_BASE_NAME="org.opencontainers.image.base.name"
declare -xr ANNOID_OPEN_IMAGE_BASE_DIGIST="org.opencontainers.image.base.digest"

if [[ ${FEDORA_VERSION+found} != found ]]; then
	FEDORA_VERSION="40"
fi
declare -xr FEDORA_VERSION

if [[ ${SHARED_SOCKET_PATH+found} != found ]]; then
	declare -xr SHARED_SOCKET_PATH=/dev/shm/container-shared-socksets
fi

function ___copy_constants_value() {
	declare -p ANNOID_CACHE_PREV_STAGE \
		ANNOID_CACHE_HASH \
		LABELID_RESULT_HASH \
		LABELID_STOP_COMMAND \
		LABELID_RELOAD_COMMAND \
		LABELID_USE_SYSTEMD \
		LABELID_USE_NGINX_ATTACH \
		ANNOID_OPEN_IMAGE_BASE_NAME \
		ANNOID_OPEN_IMAGE_BASE_DIGIST
}

register_script_emit ___copy_constants_value
