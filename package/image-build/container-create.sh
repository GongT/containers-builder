function new_container() {
	local NAME=$1
	local EXISTS
	EXISTS=$(container_find_digist "${NAME}")
	if [[ -n ${EXISTS} ]]; then
		info_log "删除已存在的容器 '${EXISTS}'"
		buildah rm "${EXISTS}" >/dev/null
	fi
	local FROM="${2-scratch}"
	if [[ ${FROM} != scratch ]] && ! is_digist "${FROM}"; then
		if is_ci; then
			info_note "[CI] 使用基础镜像 ${FROM}, 从镜像仓库拉取 (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${FROM}" >&2
		elif ! image_exists "${FROM}"; then
			info_note "缺少基础镜像 ${FROM}, 从镜像仓库拉取 (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${FROM}" >&2
		fi
	fi
	buildah from --pull=never --name "${NAME}" "${FROM}"
}

function create_if_not() {
	local NAME=$1 BASE=$2

	if is_ci; then
		info_log "[CI] 强制从镜像 '${BASE}' 创建容器 '${NAME}'."
		new_container "${NAME}" "${BASE}"
	elif [[ ${BASE} == "scratch" ]]; then
		if container_exists "${NAME}"; then
			info_log "使用已存在的容器 '${NAME}'."
			container_get_digist "${NAME}"
		else
			info_log "容器 '${NAME}' 不存在, 从 scratch 创建."
			new_container "${NAME}" "scratch"
		fi
	else
		if ! image_exists "${BASE}"; then
			info_log "缺少基础镜像 ${BASE}, 从镜像仓库拉取 (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${BASE}" >&2
		fi

		local EXISTS_CID GOT EXPECT
		EXISTS_CID=$(container_find_digist "${NAME}")
		if [[ -n ${EXISTS_CID} ]]; then
			GOT=$(container_get_base_image_id "${EXISTS_CID}")
			EXPECT=$(image_get_digist "${BASE}")
			if [[ ${EXPECT} == "${GOT}" ]]; then
				info_log "使用已存在的容器 '${NAME}'."
				container_get_digist "${NAME}"
			else
				info_log "不使用已存在的容器: ${BASE} 已更新"
				info_log "    当前镜像:      ${EXPECT}"
				info_log "    已存在容器基于: ${GOT}"
				buildah rm "${NAME}" >/dev/null
				new_container "${NAME}" "${BASE}"
			fi
		else
			info_log "容器 '${NAME}' 不存在, 从镜像 ${BASE} 创建."
			new_container "${NAME}" "${BASE}"
		fi
	fi
}
