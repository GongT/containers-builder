function add_capability() {
	_S_LINUX_CAP+=("$@")
}
function use_full_system_privilege() {
	podman_engine_params "--privileged=true"
}
function add_network_privilege() {
	# 不知道需不需要这个
	add_capability NET_ADMIN

	# networkd
	add_capability NET_RAW
	add_capability NET_BIND_SERVICE
	add_capability NET_BROADCAST

	# resolved似乎需要
	add_capability SETPCAP
}
function ___reset_cap_pri_param() {
	declare -ga _S_LINUX_CAP=(LINUX_IMMUTABLE)
}
register_unit_reset ___reset_cap_pri_param

function ___add_cap_body() {
	if [[ ${#_S_LINUX_CAP[@]} -gt 0 ]]; then
		unit_body AmbientCapabilities "${_S_LINUX_CAP[0]}"
	fi
}
register_unit_emit ___add_cap_body

function ___pass_cap_privilege_param() {
	local CAP_LIST
	if [[ ${#_S_LINUX_CAP[@]} -gt 0 ]]; then
		CAP_LIST=$(printf ",%s" "${_S_LINUX_CAP[@]}")
		add_run_argument "--cap-add=${CAP_LIST:1}"
	fi

	add_run_argument "--cgroup-parent=${_S_BODY_CONFIG[Slice]-'machine.slice'}"
}
register_argument_config ___pass_cap_privilege_param
