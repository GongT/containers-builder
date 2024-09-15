function ___reset_engine_params() {
	declare -ga ENGINE_PARAMS=()
}

register_unit_reset ___reset_engine_params

function ___emit_engine_params() {
	export_array ENGINE_PARAMS "${ENGINE_PARAMS[@]}"
}
register_script_emit ___emit_engine_params

function ___create_startup_arguments() {
	if ! variable_exists ENGINE_PARAMS; then
		die "wrong call timing _create_startup_arguments()"
	fi

	local _PODMAN_RUN_ARGS=() CAP_LIST

	call_argument_config

	ENGINE_PARAMS+=("${_PODMAN_RUN_ARGS[@]}")
	ENGINE_PARAMS+=("--pull=never" "--rm")
}
register_unit_emit ___create_startup_arguments

function add_run_argument() {
	if ! variable_exists _PODMAN_RUN_ARGS; then
		die "wrong call timing add_run_argument() should be in argument_config"
	fi
	_PODMAN_RUN_ARGS+=("$@")
}
function add_build_config() {
	if ! variable_exists _PODMAN_RUN_ARGS; then
		die "wrong call timing add_build_config() should be in argument_config"
	fi
	# noop
}

function podman_engine_params() {
	local I
	if [[ $# -eq 0 ]]; then
		return
	fi
	for I; do
		ENGINE_PARAMS+=("${I}")
	done
}
