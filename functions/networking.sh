_N_TYPE=
if [[ "${DEFAULT_USED_NETWORK+found}" == found ]]; then
	if [[ "$DEFAULT_USED_NETWORK" != "bridge" ]] && [[ "$DEFAULT_USED_NETWORK" != "gateway" ]] && [[ "$DEFAULT_USED_NETWORK" != "host" ]]; then
		die "Environment variable DEFAULT_USED_NETWORK is invalid, please set to 'bridge' or 'gateway' or 'host'."
	fi
else
	die "Environment variable DEFAULT_USED_NETWORK is not set, please set to 'bridge' or 'gateway' or 'host'."
fi

function _network_use_not_define() {
	if [[ -z "$_N_TYPE" ]]; then
		network_use_auto "$@"
	fi
}
function network_use_auto() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'auto' again."
	if [[ "$DEFAULT_USED_NETWORK" == "gateway" ]]; then
		network_use_gateway
	elif [[ "$DEFAULT_USED_NETWORK" == "host" ]]; then
		network_use_host "$@"
	else
		network_use_bridge "$@"
	fi
}
function network_use_manual() {
	_N_TYPE="manual"
	_unit_podman_network_arg "$@"
}
function network_use_bridge() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'bridge' again."
	info "Network: bridge"
	_N_TYPE="bridge"
	unit_depend "network-online.target"
	unit_unit After "firewalld.service"
	unit_unit PartOf "firewalld.service"
	unit_podman_arguments --dns=h.o.s.t
	for i; do
		_unit_podman_network_arg "--publish=$i:$i --publish=$i:$i/udp"
	done
	_create_service_library
	unit_hook_poststart "/usr/bin/flock /etc/hosts $_UPDATE_HOSTS add \"$(_unit_get_scopename)\""
	unit_hook_stop "/usr/bin/flock /etc/hosts $_UPDATE_HOSTS del \"$(_unit_get_scopename)\""
}
function network_use_container() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'gateway' again."
	info "Network: gateway"
	_N_TYPE="gateway"
	unit_depend "$1.pod.service"
	_unit_podman_network_arg "--network=container:$1"
}
function network_use_gateway() {
	network_use_container "virtual-gateway"
}
function network_use_host() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'host' again."
	info "Network: host"
	_N_TYPE="host"
	_unit_podman_network_arg "--network=host"
}
