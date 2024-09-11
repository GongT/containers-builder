

function custom_reload_command() {
	CUSTOMRELOAD_COMMAND=$(json_array "$@")
}
function custom_stop_command() {
	CUSTOMSTOP_COMMAND=$(json_array "$@")
}

function _customstop_reset() {
	declare -gi PODMAN_TIMEOUT_TO_KILL=5
	declare -g ALLOW_FORCE_KILL='yes'
	declare -g CUSTOMSTOP_COMMAND=''
	declare -g CUSTOMRELOAD_COMMAND=''
}
register_unit_reset _customstop_reset

function _stopreload_config_buildah() {
	if [[ -n "${CUSTOMSTOP_COMMAND}" ]]; then
		add_build_config "--label=${LABELID_STOP_COMMAND}=${CUSTOMSTOP_COMMAND}"
	fi
	if [[ -n "${CUSTOMRELOAD_COMMAND}" ]]; then
		add_build_config "--label=${LABELID_RELOAD_COMMAND}=${CUSTOMRELOAD_COMMAND}"
	fi
	_customstop_reset
}
register_argument_config _stopreload_config_buildah
