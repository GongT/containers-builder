function unit_podman_image_pull() {
	_S_IMAGE_PULL=$1
}
function unit_podman_image() {
	_S_IMAGE=$1
	shift

	if [[ $# -gt 0 ]]; then
		unit_podman_cmdline "$@"
	fi
}

function __reset_image_pull() {
	declare -g _S_IMAGE_PULL="${DEFAULT_IMAGE_PULL:-missing}"
	declare -g _S_IMAGE=''
}
register_unit_reset __reset_image_pull

function __emit_image_pull() {
	if [[ ${_S_IMAGE_PULL} == "never" ]]; then
		:   # Nothing
	else # always
		local _PULL_HELPER
		_PULL_HELPER=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/pull-image.sh")
		unit_hook_start "${_PULL_HELPER}" "${_S_IMAGE_PULL}"
	fi
}
register_unit_emit __emit_image_pull
