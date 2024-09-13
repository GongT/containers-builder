function network_provide_pod() {
	local -r PODNAME="${1}" NET_TYPE="${2}"
	shift
	shift
	local ARGS=("${@}") CONTENT

	if [[ ${NET_TYPE} == "veth" ]]; then
		BRIDGE="podman"
	elif [[ ${NET_TYPE} == "veth:"* ]]; then
		BRIDGE="service-${NET_TYPE#*:}.network"
	else
		die "network_provide_pod: current not support network type: ${NET_TYPE}"
	fi
	local NET_UNIT=""

	CONTENT="[Unit]
# After=${NET_UNIT}
# Requires=${NET_UNIT}

[Pod]
PodName=${PODNAME}
Network=${BRIDGE}
PodmanArgs=--exit-policy=continue $(emit_bash_arguments "${ARGS[@]}")

[Service]
Slice=services.slice

[X-Container]
ARGUMENTS=${ARGS[*]}
"
	write_file "${PODMAN_QUADLET_DIR}/service-${PODNAME}.pod" "${CONTENT}"
}
