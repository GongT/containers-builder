function custom_reload_command() {
	CUSTOMRELOAD_COMMAND=("$@")
}
function custom_stop_command() {
	CUSTOMSTOP_COMMAND=("$@")
}

function _customstop_reset() {
	declare -gi PODMAN_TIMEOUT_TO_KILL=5
	declare -g ALLOW_FORCE_KILL='yes'
	declare -ga CUSTOMSTOP_COMMAND=()
	declare -ga CUSTOMRELOAD_COMMAND=()
}
register_unit_reset _customstop_reset

function _stopreload_config_buildah() {
	local S
	if [[ ${#CUSTOMSTOP_COMMAND[@]} -gt 0 ]]; then
		S=$(json_array "${CUSTOMSTOP_COMMAND[@]}")
		add_build_config "--label=${LABELID_STOP_COMMAND}=$(json_array "${CUSTOMSTOP_COMMAND[@]}")"
	fi
	if [[ ${#CUSTOMRELOAD_COMMAND[@]} -gt 0 ]]; then
		S=$(json_array "${CUSTOMRELOAD_COMMAND[@]}")
		add_build_config "--label=${LABELID_RELOAD_COMMAND}=$(json_array "${CUSTOMRELOAD_COMMAND[@]}")"
	fi
	_customstop_reset
}
register_argument_config _stopreload_config_buildah

function __stopreload_env_set() {
	unit_body Environment "ALLOW_FORCE_KILL=${ALLOW_FORCE_KILL}" "PODMAN_TIMEOUT_TO_KILL=${PODMAN_TIMEOUT_TO_KILL}"
}
register_unit_emit __stopreload_env_set

function unit_data() {
	if [[ $1 == "safe" ]]; then
		PODMAN_TIMEOUT_TO_KILL=30
		ALLOW_FORCE_KILL=yes
	elif [[ $1 == "danger" ]]; then
		PODMAN_TIMEOUT_TO_KILL=100
		ALLOW_FORCE_KILL=no

		_S_UNIT_CONFIG[TimeoutAbortSec]=120s
		_S_UNIT_CONFIG[TimeoutStartFailureMode]=abort
		_S_UNIT_CONFIG[TimeoutStopFailureMode]=abort
	else
		die "unit_data <safe|danger>"
	fi
}
