declare -a _HANDLERS_RESET=() _HANDLERS_EMIT_UNIT=() _HANDLERS_EMIT_SRC=() _HANDLERS_ARGUMENTS=()

function __call_array() {
	local handler
	for handler; do
		if [[ ${pre_eval+def} ]]; then
			"${pre_eval}" "${handler}"
		fi
		if ! eval "${handler}"; then
			die "while execute function: ${handler}"
		fi
	done
}
function register_unit_reset() {
	_HANDLERS_RESET+=("$*")
	"$*"
}
function call_unit_reset() {
	__call_array "${_HANDLERS_RESET[@]}"
}

function register_unit_emit() {
	_HANDLERS_EMIT_UNIT+=("$*")
}
function call_unit_emit() {
	__call_array "${_HANDLERS_EMIT_UNIT[@]}"
}

function register_script_emit() {
	_HANDLERS_EMIT_SRC+=("$*")
}
function __print_hook_name() {
	printf '### HOOK: %s\n' "$1"
}
function call_script_emit() {
	local pre_eval="__print_hook_name"
	__call_array "${_HANDLERS_EMIT_SRC[@]}"
}

function register_argument_config() {
	_HANDLERS_ARGUMENTS+=("$*")
}
function call_argument_config() {
	__call_array "${_HANDLERS_ARGUMENTS[@]}"
}
