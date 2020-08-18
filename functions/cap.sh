function add_capability() {
	_S_LINUX_CAP+=("$@")
}
function use_full_system_privilege() {
	_S_LINUX_CAP=()
	unit_podman_arguments "--privileged=true"
}
function add_network_privilege() {
	add_capability NET_ADMIN
}
