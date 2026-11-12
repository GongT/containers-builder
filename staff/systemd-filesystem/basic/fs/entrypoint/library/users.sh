# 用户和用户组管理相关函数

# 使用方法: system_ensure_user <用户ID> <用户名> <用户组ID或名称>
function system_ensure_user() {
	local U_ID=$1 U_NAME=$2 G_ID_OR_NAME=$3 EX_UID
	if user_exists "${U_NAME}"; then
		EX_UID=$(get_uid_of_user "${U_NAME}")
		log "用户 ${U_NAME} 已存在，id 为 ${EX_UID}"
		if [[ ${EX_UID} -ne ${U_ID} ]]; then
			log "用户 ${U_NAME} 的id不同 (${EX_UID} != ${U_ID})，正在更新..."
			usermod -u "${U_ID}" "${U_NAME}"
		fi
	else
		local G_ID
		G_ID=$(get_gid_of_group "${G_ID_OR_NAME}")

		useradd --gid "${G_ID}" --home-dir "/home/${U_NAME}" --no-create-home --no-user-group --uid "$U_ID" "${U_NAME}"
		log "新建系统用户 ${U_NAME} ($(get_uid_of_user "${U_NAME}" || true))"
	fi
}

# 使用方法: system_ensure_group <用户组ID> <用户组名>
function system_ensure_group() {
	local G_ID=$1 G_NAME=$2 EX_GID
	if group_exists "${G_NAME}"; then
		EX_GID=$(get_gid_of_group "${G_NAME}")
		log "用户组 ${G_NAME} 已存在，id 为 ${EX_GID}"
		if [[ ${EX_GID} -ne ${G_ID} ]]; then
			log "用户组 ${G_NAME} 的id不同 (${EX_GID} != ${G_ID})，正在更新..."
			groupmod -g "${G_ID}" "${G_NAME}"
		fi
	else
		groupadd -g "${G_ID}" "${G_NAME}"
		log "新建系统用户组 ${G_NAME} ($(get_gid_of_group "${G_NAME}" || true))"
	fi
}

function get_gid_of_group() {
	{ getent group "$1" 2>/dev/null || true; } | cut -d: -f3
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

# 使用方法: ensure_user_exists <用户名>
# 创建的用户处于 users 用户组
function ensure_user_exists() {
	local U_NAME=$1
	if user_exists "${U_NAME}"; then
		log "用户 ${U_NAME} 已存在，id 为 $(get_uid_of_user "${U_NAME}" || true)"
	else
		local G_ID
		G_ID=$(get_gid_of_group "users")

		useradd --gid "${G_ID}" --no-create-home --no-user-group "${U_NAME}"
		log "新建系统用户 ${U_NAME} ($(get_uid_of_user "${U_NAME}" || true))"
	fi
}
