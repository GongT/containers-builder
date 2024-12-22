if [[ ${DEFAULT_USED_NETWORK+found} == found ]]; then
	if [[ ${DEFAULT_USED_NETWORK} == "gateway" ]]; then
		info_warn "gateway is renamed to pod, please update your environment."
		export DEFAULT_USED_NETWORK=pod
	fi
	if [[ ${DEFAULT_USED_NETWORK} == "bridge" ]]; then
		info_warn "bridge is renamed to veth, please update your environment."
		export DEFAULT_USED_NETWORK=veth
	fi
	if [[ ${DEFAULT_USED_NETWORK} != "pod"* ]] && [[ ${DEFAULT_USED_NETWORK} != "host" ]] && [[ ${DEFAULT_USED_NETWORK} != "veth"* ]]; then
		die "Environment variable DEFAULT_USED_NETWORK is invalid, please set to 'veth[:*]' or 'pod[:*]' or 'host'."
	fi
else
	die "Environment variable DEFAULT_USED_NETWORK is not set, please set to 'veth[:*]' or 'pod[:*]' or 'host'."
fi

function _unit_podman_network_arg() {
	_N_NETWORK_ARG+=("$@")
}

function __network_settings_emit() {
	if [[ -z ${_N_TYPE} ]]; then
		network_use_default
	fi
	local HN=${_N_HOST:-$(unit_get_scopename)}
	unit_body "Environment" "MY_HOSTNAME=$HN"
}
register_unit_emit __network_settings_emit

function _network_reset() {
	declare -g _N_TYPE=''
	declare -g _N_HOST=''
	declare -ga _N_PORTS=()
	declare -ga _N_NETWORK_ARG=()
}
register_unit_reset _network_reset

function _export_network_envs() {
	printf 'declare -r NETWORK_TYPE=%q\n' "${_N_TYPE}"
}
register_script_emit _export_network_envs

function ___push_network_args() {
	add_run_argument "${_N_NETWORK_ARG[@]}"
}
register_argument_config ___push_network_args

function _append_network_args() {
	if [[ ${_N_TYPE} != 'pod' ]]; then
		add_run_argument "--hostname=${_N_HOST:-$(unit_get_scopename)}"
	fi
}
register_argument_config _append_network_args

function unit_podman_hostname() {
	if [[ -n ${_N_HOST} ]]; then
		die "hostname already set to ${_N_HOST}"
	fi
	_N_HOST=$1
}

function _record_port_usage() {
	_N_PORTS+=("$@")
}
function _net_set_type() {
	local SET_TO="$1"
	[[ -z ${_N_TYPE} ]] || die "Network already set to ${_N_TYPE}, can not set to '${SET_TO}' again."
	info "Network: ${SET_TO}"
	_N_TYPE="${SET_TO}"
}

function network_use_auto() {
	info_warn "network_use_auto is renamed to network_use_default, please update your script."
	callstack
	network_use_default "$@"
}

function network_use_default() {
	[[ -z ${_N_TYPE} ]] || die "Network already set to ${_N_TYPE}, can not set to 'auto' again."
	if [[ ${DEFAULT_USED_NETWORK} == "host" ]]; then
		network_use_host "$@"
	elif [[ ${DEFAULT_USED_NETWORK} == "pod" ]]; then
		network_use_pod default "$@"
	elif [[ ${DEFAULT_USED_NETWORK} == "pod:"* ]]; then
		network_use_pod "${DEFAULT_USED_NETWORK#pod:}" "$@"
	elif [[ ${DEFAULT_USED_NETWORK} == "veth:"* ]]; then
		network_use_veth "${DEFAULT_USED_NETWORK#veth:}" "$@"
	else
		network_use_veth podman "$@"
	fi
}
function network_use_manual() {
	# do not do any network related job
	_net_set_type "manual"
	info_warn "using manual network type."
	_unit_podman_network_arg "$@"
}
function network_use_void() {
	# do not do any network related job
	_net_set_type "void"
	info_warn "using void network type."
	_unit_podman_network_arg "--network=private"
}

# function network_use_macvlan() {
# create macvlan and pass one end into container
# _net_set_type "macvlan"
# die "not impl"
# }

function network_use_interface() {
	# exclusive move host interface into container
	#     network_use_interface <ifname_on_host> [ifname_inside_container = eth0]
	local -r IFNAME=$1 DIST_NAME=${2:-eth0}
	local SCRIPT

	if [[ ${NET_NAMESPACE+found} != found ]]; then
		local NET_NAMESPACE
		NET_NAMESPACE="service-${_S_CURRENT_UNIT_NAME}"
	fi

	_net_set_type "exclusive"
	_unit_podman_network_arg "--network=ns:/var/run/netns/${NET_NAMESPACE}" --no-hosts

	SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/network-move-interface.sh")
	unit_hook_start "+${SCRIPT} 'INTERFACE_NAME=${IFNAME}' 'INTERFACE_NAME_INSIDE=${DIST_NAME}' NET_NAMESPACE='${NET_NAMESPACE}'"
	unit_hook_stop "+-${SCRIPT} --out 'INTERFACE_NAME=${IFNAME}' 'INTERFACE_NAME_INSIDE=${DIST_NAME}' NET_NAMESPACE='${NET_NAMESPACE}'"

	add_network_privilege

	if [[ -n ${DIST_NAME} ]]; then
		podman_engine_params --env="INTERFACE_NAME=${DIST_NAME}"
	else
		podman_engine_params --env="INTERFACE_NAME=${INTERFACE_NAME}"
	fi
}

function network_use_veth() {
	# use the most common network type
	if [[ $# -eq 0 ]]; then
		set -- 'podman'
	fi
	local BRIDEG_NAME=$1
	shift
	local PORT_FORWARD=("$@")
	local SCRIPT

	_net_set_type "veth"
	_record_port_usage "${PORT_FORWARD[@]}"

	if [[ -e "${PODMAN_QUADLET_DIR}/service-${BRIDEG_NAME}.network" ]]; then
		unit_depend "service-${BRIDEG_NAME}-network.service"
	else
		unit_unit After "service-${BRIDEG_NAME}-network.service"
		if [[ ${BRIDEG_NAME} != podman ]] && [[ ! -e "${PODMAN_QUADLET_DIR}/service-${BRIDEG_NAME}.network" ]]; then
			info_warn "bridge network may not exists: ${BRIDEG_NAME}"
		fi
	fi
	podman_engine_params "--network=${BRIDEG_NAME}"

	if is_root; then
		unit_depend "network-online.target" "nameserver.service"
		unit_unit After "firewalld.service"
	else
		podman_engine_params --dns=h.o.s.t
	fi

	local i
	for i in "${PORT_FORWARD[@]}"; do
		local from="" to="" proto=""
		if [[ ${i} == *":"* ]]; then
			from="${i%%:*}"
			i="${i##*:}"
			to="${i%%/*}"
		else
			from="${i%%/*}"
			to="${i%%/*}"
		fi
		if [[ ${i} == *"/"* ]]; then
			proto="${i##*/}"
			_unit_podman_network_arg "--publish=${from}:${to}/${proto}"
		else
			_unit_podman_network_arg "--publish=${from}:${to}/tcp" "--publish=${from}:${to}/udp"
		fi
	done

	if is_root; then
		SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/update-hosts.sh")
		unit_hook_poststart '+-/usr/bin/flock' /etc/hosts "${SCRIPT}" add
		unit_hook_stop '+-/usr/bin/flock' /etc/hosts "${SCRIPT}" del
	fi
}
function network_use_container() {
	# join another container's network namespace
	local CONTAINER_NAME=$1 PORT_FORWARD=("$@")
	local SCRIPT

	_net_set_type "container"
	_record_port_usage "${PORT_FORWARD[@]}"

	unit_unit After "$1.pod.service"
	SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/network-wait-continaer.sh")
	unit_hook_start "+${SCRIPT} '${CONTAINER_NAME}'"
	_unit_podman_network_arg "--network=container:$1"
}
function network_use_pod() {
	# use a "pod"
	local PODNAME="${1}"
	shift

	_net_set_type "pod"
	_record_port_usage "$@"

	if [[ -e "${PODMAN_QUADLET_DIR}/service-${PODNAME}.pod" ]]; then
		unit_depend "service-${PODNAME}-pod.service"
		unit_unit PartOf "service-${PODNAME}-pod.service"
	else
		info_warn "pod may not exists: ${PODMAN_QUADLET_DIR}/service-${PODNAME}.pod"

		local SCRIPT
		SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/network-wait-pod.sh")
		unit_hook_start "${SCRIPT}" "${PODNAME}"
	fi
	_unit_podman_network_arg "--pod=${PODNAME}"
}
function network_use_host() {
	# do not use network namespace, dangerouse
	_net_set_type "host"
	_record_port_usage "$@"

	_unit_podman_network_arg "--network=host"
}

function network_define_nat() {
	local -r NET_NAME="$1" IP_CONFIG_STR="$2"
	local IP_CONFIG

	info_success "creating network: ${NET_NAME} [${IP_CONFIG_STR}]"
	IP_CONFIG=$(ipcalc --json "${IP_CONFIG_STR}")

	if [[ ${IP_CONFIG} != *"Private Use"* ]]; then
		info_warn "    using network IP range, it's best to use a private range."
	fi

	CONTENT="[Unit]
After=systemd-networkd.service network-online.target

[Network]
NetworkName=${NET_NAME}
Internal=false
IPv6=true
DisableDNS=true
GlobalArgs=--log-level=debug
IPAMDriver=host-local
Subnet=$(echo "${IP_CONFIG}" | jq -r '.NETWORK + "/" + .PREFIX')
PodmanArgs=--interface-name=${NET_NAME}

[Service]
Slice=services.slice
"

	write_file "${PODMAN_QUADLET_DIR}/service-${NET_NAME}.network" "${CONTENT}"
}
function network_define_macvlan_interface() {
	if ! is_root; then
		die "bridge network only valid for root user"
	fi

	local -r NET_NAME="${1}"
	local MTU CONTENT

	if ! MTU=$(ip --json --pretty link show "${NET_NAME}" | jq -r '.[0].mtu'); then
		die "missing interface: ${NET_NAME}"
	fi

	if brctl show "${NET_NAME}" >/dev/null; then
		info_success "create network of pre-exists bridge: ${NET_NAME}"
	else
		info_success "create network bridge to interface: ${NET_NAME}"
	fi

	CONTENT="[Unit]
After=systemd-networkd.service network-online.target
RequiresMountsFor=/var/lib/containers/storage

[Network]
NetworkName=${NET_NAME}
Internal=false
IPv6=true
DisableDNS=true
GlobalArgs=--log-level=debug
### TODO: how to set ipam driver?
IPAMDriver=none
Options=mtu=${MTU}
Driver=macvlan
# Options=no_default_route=0
PodmanArgs=--interface-name=${NET_NAME}

[Service]
Slice=services.slice
Restart=on-failure
RestartSec=30s
"

	write_file "${PODMAN_QUADLET_DIR}/service-${NET_NAME}.network" "${CONTENT}"
}
