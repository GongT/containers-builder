function ___reset_cmdline() {
	declare -ga _S_COMMAND_LINE=()
}

register_unit_reset ___reset_cmdline

function ___emit_cmdline() {
	export_array COMMAND_LINE "${_S_COMMAND_LINE[@]}"
}
register_script_emit ___emit_cmdline

function unit_podman_cmdline() {
	if [[ ${#_S_COMMAND_LINE[@]} -gt 0 ]]; then
		info_warn "duplicate set commandline, last one will used"
	fi
	_S_COMMAND_LINE=("$@")
}
