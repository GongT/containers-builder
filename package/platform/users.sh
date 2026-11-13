# 确保指定的用户存在，如果不存在则创建该用户
# 用户的主组是users，需确保该组存在
# @param $1 用户名
# @param $2 用户ID，可选，默认系统分配
# @param $3 用户主组ID或名称，可选，默认自动分配。设置为ID时该组必须存在，设为名称时如果不存在则会自动创建
function ensure_user() {
	local U_NAME=$1 U_ID=${2-} G_ID_NAME=${3-}
	local R_UID GID

	if [[ -n ${G_ID_NAME} ]]; then
		# 如果指定了主组，先检查该组是否存在，并获取其GID
		if group_exists "${G_ID_NAME}"; then
			GID=$(get_gid_of_group "${G_ID_NAME}")
		elif [[ ${G_ID_NAME} =~ ^[0-9]+$ ]]; then
			# 设置主组ID数字，但不存在，无法可靠创建
			die "新用户创建失败: 指定的主组 ${G_ID_NAME} 是ID但不存在"
		else
			# 如果指定的主组是名称但不存在，则创建该组
			ensure_group "${G_ID_NAME}"
			GID=$(get_gid_of_group "${G_ID_NAME}")
		fi
	fi
	unset G_ID_NAME

	if ! user_exists "${U_NAME}"; then
		# 用户不存在，直接创建
		local A_ARG=()
		if [[ -n ${GID} ]]; then
			A_ARG=(--gid "${GID}" --no-user-group)
		else
			A_ARG=(--user-group)
		fi
		if [[ -n ${U_ID} ]]; then
			A_ARG+=(--uid "$U_ID")
		fi
		useradd "${A_ARG[@]}" --no-create-home "${U_NAME}"
		info_success "新建系统用户 ${U_NAME}, id: $(get_uid_of_user "${U_NAME}"), 组: $(id -g "${U_NAME}")"
		return 0
	fi

	if [[ -n ${U_ID} ]]; then
		R_UID=$(get_uid_of_user "${U_NAME}")
		if [[ ${R_UID} -ne ${U_ID} ]]; then
			usermod -u "${U_ID}" "${U_NAME}"
			info_warn "用户 ${U_NAME} 的 id 已由 ${R_UID} 修改为 ${U_ID}"
		fi
	fi

	if [[ -n ${GID} ]]; then
		R_GID=$(get_gid_of_group "${GID}")
		if [[ ${R_GID} -ne ${GID} ]]; then
			groupmod -g "${GID}" "${G_ID_NAME}"
			info_warn "用户 ${U_NAME} 的主组 id 已由 ${R_GID} 修改为 ${GID}"
		fi
	fi

	info_note "用户 ${U_NAME} 已存在, id: $(get_uid_of_user "${U_NAME}"), 组: $(id -g "${U_NAME}")"
}

# 确保指定的用户组存在，如果不存在则创建该组
# @param $1 用户组名称
# @param $2 用户组ID，可选，默认系统分配
function ensure_group() {
	local G_NAME=$1 G_ID=${2-} EX_GID

	if group_exists "${G_NAME}"; then
		EX_GID=$(get_gid_of_group "${G_NAME}")
		if [[ -n ${G_ID} && ${EX_GID} -ne ${G_ID} ]]; then
			groupmod -g "${G_ID}" "${G_NAME}"
			info_warn "用户组 ${G_NAME} 的 id 已由 ${EX_GID} 修改为 ${G_ID}"
			else
			info_note "用户组 ${G_NAME} 已存在, id 为 ${EX_GID}"
		fi
	else
		local A_ARG=()
		[[ -n ${G_ID} ]] && A_ARG+=(-g "${G_ID}")
		groupadd "${A_ARG[@]}" "${G_NAME}"
		info_success "新建系统用户组 ${G_NAME} ($(get_gid_of_group "${G_NAME}"))"
	fi
}

function get_gid_of_group() {
	getent group "$1" 2>/dev/null | cut -d: -f3
}

function get_uid_of_user() {
	id -u "$1" 2>/dev/null
}

function user_exists() {
	getent passwd "$1" &>/dev/null
}

function group_exists() {
	getent group "$1" &>/dev/null
}
