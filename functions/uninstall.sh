_F_UNINSTALL=""
function is_uninstalling() {
	[[ -n "$_F_UNINSTALL" ]]
}
function is_installing() {
	[[ -z "$_F_UNINSTALL" ]]
}
arg_flag _F_UNINSTALL uninstall "uninstall (remove files)"
