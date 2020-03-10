_N_TYPE=
if [[ "${DEFAULT_USED_NETWORK+found}" == found ]]; then
	if [[ "$DEFAULT_USED_NETWORK" != "bridge" ]] && [[ "$DEFAULT_USED_NETWORK" != "gateway" ]]; then
		die "Environment variable DEFAULT_USED_NETWORK is invalid, please set to 'bridge' or 'gateway'."
	fi
else
	die "Environment variable DEFAULT_USED_NETWORK is not set, please set to 'bridge' or 'gateway'."
fi

function _network_use_not_define() {
	if [[ -z "$_N_TYPE" ]] ; then
		network_use_auto
	fi
}
function network_use_auto() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'auto' again."
	if [[ "$DEFAULT_USED_NETWORK" == "bridge" ]]; then
		network_use_bridge "$@"
	else
		network_use_gateway
	fi
}
function network_use_bridge() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'bridge' again."
	info "Network: bridge"
	_N_TYPE="bridge"
	unit_depend "firewalld.service network-online.target"
	unit_unit PartOf "firewalld.service"
	for i ; do
		_unit_podman_network_arg "--publish=$i:$i --publish=$i:$i/udp"
	done
}
function network_use_gateway() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'gateway' again."
	info "Network: gateway"
	_N_TYPE="gateway"
	unit_depend "virtual-gateway.service"
	_unit_podman_network_arg "--network=container:virtual-gateway"
}
function network_use_host() {
	[[ -z "$_N_TYPE" ]] || die "Network already set to $_N_TYPE, can not set to 'host' again."
	info "Network: host"
	_N_TYPE="host"
	_unit_podman_network_arg "--network=host"
}
