_N_TYPE=
if [[ ${DEFAULT_USED_NETWORK+found} == found ]]; then
	if [[ $DEFAULT_USED_NETWORK != "bridge" ]] && [[ $DEFAULT_USED_NETWORK != "gateway" ]] && [[ $DEFAULT_USED_NETWORK != "host" ]] && [[ $DEFAULT_USED_NETWORK != "nat" ]]; then
		die "Environment variable DEFAULT_USED_NETWORK is invalid, please set to 'nat' or 'gateway' or 'host'."
	fi
	if [[ $DEFAULT_USED_NETWORK == "bridge" ]]; then
		export DEFAULT_USED_NETWORK=nat
	fi
else
	die "Environment variable DEFAULT_USED_NETWORK is not set, please set to 'nat' or 'gateway' or 'host'."
fi

function _network_use_not_define() {
	if [[ -z $_N_TYPE ]]; then
		network_use_auto "$@"
	fi
}
function network_use_auto() {
	[[ -z $_N_TYPE ]] || die "Network already set to $_N_TYPE, can not set to 'auto' again."
	if [[ $DEFAULT_USED_NETWORK == "gateway" ]]; then
		network_use_gateway
	elif [[ $DEFAULT_USED_NETWORK == "host" ]]; then
		network_use_host "$@"
	else
		network_use_nat "$@"
	fi
}
function network_use_manual() {
	_N_TYPE="manual"
	_unit_podman_network_arg "$@"
}

function network_use_macvlan() {
	die "not impl"
}

function network_use_interface() {
	local -r IFNAME=$1 DIST_NAME=${2:-}
	local SCRIPT

	if [[ ${NET_NAMESPACE+found} != found ]]; then
		local NET_NAMESPACE
		NET_NAMESPACE="mypod-$(_unit_get_name)"
	fi

	_N_TYPE="exclusive"
	_unit_podman_network_arg "--network=ns:/var/run/netns/$NET_NAMESPACE" --no-hosts

	SCRIPT=$(install_script "$COMMON_LIB_ROOT/tools/move-interface.sh")
	unit_hook_start "+/usr/bin/bash $SCRIPT 'INTERFACE_NAME=$IFNAME' 'INTERFACE_NAME_INSIDE=$DIST_NAME' NET_NAMESPACE='${NET_NAMESPACE}'"
	unit_hook_stop "+-/usr/bin/bash $SCRIPT --out 'INTERFACE_NAME=$IFNAME' 'INTERFACE_NAME_INSIDE=$DIST_NAME' NET_NAMESPACE='${NET_NAMESPACE}'"

	add_network_privilege

	if [[ $DIST_NAME ]]; then
		unit_podman_arguments --env="INTERFACE_NAME=$DIST_NAME"
	else
		unit_podman_arguments --env="INTERFACE_NAME=$INTERFACE_NAME"
	fi
}

function network_use_bridge() {
	info_warn "[network_use_bridge] use network_use_nat instead"
	network_use_nat
}

# use podman0
function network_use_nat() {
	[[ -z $_N_TYPE ]] || die "Network already set to $_N_TYPE, can not set to 'nat' again."
	info "Network: NAT"
	_N_TYPE="nat"
	unit_depend "network-online.target"
	unit_unit After "firewalld.service" "nameserver.service"
	unit_unit Requires "nameserver.service"
	unit_unit PartOf "firewalld.service"
	unit_podman_arguments --dns=h.o.s.t
	local i
	for i; do
		local from="" to="" proto=""
		if [[ $i == *":"* ]]; then
			from="${i%%:*}"
			i="${i##*:}"
			to="${i%%/*}"
		else
			from="${i%%/*}"
			to="${i%%/*}"
		fi
		if [[ $i == *"/"* ]]; then
			proto="${i##*/}"
			_unit_podman_network_arg "--publish=$from:$to/$proto"
		else
			_unit_podman_network_arg "--publish=$from:$to/tcp --publish=$from:$to/udp"
		fi
	done
	_create_service_library
	unit_hook_poststart "/usr/bin/flock /etc/hosts $_UPDATE_HOSTS add \"$(_unit_get_scopename)\" \"$_S_HOST\""
	unit_hook_stop "/usr/bin/flock /etc/hosts $_UPDATE_HOSTS del \"$(_unit_get_scopename)\""
}
function network_use_container() {
	[[ -z $_N_TYPE ]] || die "Network already set to $_N_TYPE, can not set to 'gateway' again."
	info "Network: gateway"
	_N_TYPE="gateway"
	unit_depend "$1.pod.service"
	_unit_podman_network_arg "--network=container:$1"
}
function network_use_gateway() {
	network_use_container "virtual-gateway"
}
function network_use_host() {
	[[ -z $_N_TYPE ]] || die "Network already set to $_N_TYPE, can not set to 'host' again."
	info "Network: host"
	_N_TYPE="host"
	_unit_podman_network_arg "--network=host"
}
