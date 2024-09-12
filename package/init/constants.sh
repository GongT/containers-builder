declare -xr ANNOID_CACHE_PREV_STAGE="me.gongt.cache.prevstage"
declare -xr ANNOID_CACHE_HASH="me.gongt.cache.hash"
declare -xr LABELID_RESULT_HASH="me.gongt.hash"
declare -xr LABELID_STOP_COMMAND="me.gongt.cmd.stop"
declare -xr LABELID_RELOAD_COMMAND="me.gongt.cmd.reload"
declare -xr LABELID_SYSTEMD="me.gongt.using.systemd"

declare -xr ANNOID_OPEN_IMAGE_BASE_NAME="org.opencontainers.image.base.name"
declare -xr ANNOID_OPEN_IMAGE_BASE_DIGIST="org.opencontainers.image.base.digest"

if [[ ${FEDORA_VERSION+found} != found ]]; then
	FEDORA_VERSION="40"
fi
declare -xr FEDORA_VERSION

declare -r SHARED_SOCKET_PATH=/dev/shm/container-shared-socksets
