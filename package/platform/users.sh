function ensure_user() {
	local U_ID=$1 U_NAME=$2 G_ID_OR_NAME=$3
	if user_exists "${U_NAME}"; then
		local EX_UID=$(get_uid_of_user "${U_NAME}")
		if [[ ${EX_UID} -eq ${U_ID} ]]; then
			info_note "User ${U_NAME} exists with id ${EX_UID}"
		else
			info_warn "User ${U_NAME} has a different id: exists=${EX_UID}, want=${U_ID}"
		fi
	else
		local G_ID
		G_ID=$(get_gid_of_group "${G_ID_OR_NAME}")

		useradd --gid "${G_ID}" --no-create-home --no-user-group --uid "$U_ID" "${U_NAME}"
		info_success "new system user ${U_NAME} ($(get_uid_of_user "${U_NAME}"))"
	fi
}

function ensure_group() {
	local G_ID=$1 G_NAME=$2
	if group_exists "${G_NAME}"; then
		local EX_GID=$(get_gid_of_group "${G_NAME}")
		if [[ ${EX_GID} -eq ${G_ID} ]]; then
			info_note "Group ${G_NAME} exists with id ${EX_GID}"
		else
			info_warn "Group ${G_NAME} has a different id: exists=${EX_GID}, want=${G_ID}"
		fi
	else
		groupadd -g "${G_ID}" "${G_NAME}"
		info_success "new system group ${G_NAME} ($(get_gid_of_group "${G_NAME}"))"
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

function ensure_user_exists() {
	local U_NAME=$1
	if user_exists "${U_NAME}"; then
		info_note "User ${U_NAME} exists with id $(get_uid_of_user "${U_NAME}")"
	else
		local G_ID
		G_ID=$(get_gid_of_group "users")

		useradd --gid "${G_ID}" --no-create-home --no-user-group "${U_NAME}"
		info_success "new system user ${U_NAME} ($(get_uid_of_user "${U_NAME}"))"
	fi
}
