#!/usr/bin/env bash
set -Eeuo pipefail

function find_bridge_ip() {
	podman network inspect podman | grep -oE '"gateway": ".+",?$' | sed 's/"gateway": "\(.*\)".*/\1/g'
}

declare HOST_IP=""
function detect_host_ip() {
	if [[ $NETWORK_TYPE == "host" ]]; then
		HOST_IP="127.0.0.1"
	elif [[ $NETWORK_TYPE == "bridge" ]]; then
		HOST_IP=$(find_bridge_ip)
		if ! [[ "$HOST_IP" ]]; then
			critical_die "Can not get information about default podman network (podman0), podman configure failed."
		fi
	else
		HOST_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
	fi

	debug "Local host access address: $HOST_IP"
	ARGS+=("--env=HOSTIP=$HOST_IP")
}
