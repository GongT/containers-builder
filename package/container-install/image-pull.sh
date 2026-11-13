function unit_podman_image_pull() {
	_S_IMAGE_PULL=$1
}

declare -r VALID_IMAGE_NAME='^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+(?::[0-9]+)?(?:/[^/?#]+){2,}/?$'
declare -r VALID_WITHOUT_DOMAIN='^[^/?#]+/[^/?#]+$'

function sanity_image_name() {
	local NAME="$1"

	if [[ ${DEBUG_MODE} == "yes" ]]; then
		echo "$NAME"
		return
	fi

	# 检查镜像名称是否符合规范: domain.com/user/repo/...
	if echo "$NAME" | grep -Pq "$VALID_IMAGE_NAME"; then
		# 完整名称
		echo "$NAME"
	elif echo "$NAME" | grep -Pq "$VALID_WITHOUT_DOMAIN"; then
		if [[ -n ${PODMAN_IMAGE_REGISTRY:-} ]]; then
			echo "${PODMAN_IMAGE_REGISTRY}/$NAME"
		else
			die "缺少 PODMAN_IMAGE_REGISTRY 环境变量，无法补全镜像名称"
		fi
	else
		die "镜像名称不合法: $NAME"
	fi
}

function unit_podman_image() {
	_S_IMAGE=$(sanity_image_name "$1")
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
		: # Nothing
	else # always
		local _PULL_HELPER
		_PULL_HELPER=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/pull-image.sh")
		unit_hook_start "${_PULL_HELPER}" "${_S_IMAGE_PULL}"
	fi
}
register_unit_emit __emit_image_pull
