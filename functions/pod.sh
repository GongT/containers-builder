function network_provide_pod() {
	local -r PODNAME="${1}" NET_TYPE="${2}"
	shift
	shift
	local ARGS=("${@}") CONTENT

	if [[ $NET_TYPE == "veth" ]]; then
		BRIDGE="podman"
	elif [[ $NET_TYPE == "veth:"* ]]; then
		BRIDGE="${NET_TYPE# veth:}.network"
	else
		die "network_provide_pod: current not support network type: $NET_TYPE"
	fi

	CONTENT="[Unit]
	
[Pod]
ServiceName=service-pod-$PODNAME
PodName=$PODNAME
DNS=none
Network=${NET_TYPE}
PodmanArgs=$(emit_bash_arguments "${ARGS[@]}")

[Service]
Slice=services.slice

[X-Container]
ARGUMENTS=${ARGS[*]}
"
	write_file "$PODMAN_QUADLET_DIR/service-pod-$PODNAME.pod" "$CONTENT"
}
