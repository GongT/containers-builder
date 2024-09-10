function is_uninstalling() {
	[[ -n "${_ACTION_UNINSTALL}" ]]
}
function is_installing() {
	[[ -z "${_ACTION_UNINSTALL}" ]]
}
arg_flag _ACTION_UNINSTALL uninstall "uninstall (remove files)"
