function custom_reload_command() {
	CUSTOMRELOAD_COMMAND=$(json_array "$@")
}
function custom_stop_command() {
	CUSTOMSTOP_COMMAND=$(json_array "$@")
}

function _customstop_reset() {
	CUSTOMSTOP_COMMAND=''
	CUSTOMRELOAD_COMMAND=''
}
register_unit_reset _customstop_reset

function _stopreload_config_buildah() {
	if [[ -n "${CUSTOMSTOP_COMMAND}" ]]; then
		_add_config "--label=${LABELID_STOP_COMMAND}=${CUSTOMSTOP_COMMAND}"
	fi
	if [[ -n "${CUSTOMRELOAD_COMMAND}" ]]; then
		_add_config "--label=${LABELID_RELOAD_COMMAND}=${CUSTOMRELOAD_COMMAND}"
	fi
	_customstop_reset
}
