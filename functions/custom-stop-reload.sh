CUSTOMSTOP_COMMAND=""
CUSTOMRELOAD_COMMAND=""

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

function _stopreload_config_buildah() {
	if [[ "$CUSTOMSTOP_COMMAND" ]]; then
		_add_config "--label=$LABELID_STOP_COMMAND=$CUSTOMSTOP_COMMAND"
	fi
	if [[ "$CUSTOMRELOAD_COMMAND" ]]; then
		_add_config "--label=$LABELID_RELOAD_COMMAND=$CUSTOMRELOAD_COMMAND"
	fi
	_customstop_reset
}
