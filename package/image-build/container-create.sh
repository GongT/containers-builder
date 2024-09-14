function new_container() {
	local NAME=$1
	local EXISTS
	EXISTS=$(container_find_id "${NAME}")
	if [[ -n ${EXISTS} ]]; then
		info_log "remove exists container '${EXISTS}'"
		buildah rm "${EXISTS}" >/dev/null
	fi
	local FROM="${2-scratch}"
	if [[ ${FROM} != scratch ]] && ! is_id_digist "${FROM}"; then
		if is_ci; then
			info_note "[CI] base image ${FROM}, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${FROM}" >&2
		elif ! image_exists "${FROM}"; then
			info_note "missing base image ${FROM}, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${FROM}" >&2
		fi
	fi
	buildah from --pull=never --name "${NAME}" "${FROM}"
}

function create_if_not() {
	local NAME=$1 BASE=$2

	if is_ci; then
		info_log "[CI] force create container '${NAME}' from image '${BASE}'."
		new_container "${NAME}" "${BASE}"
	elif [[ ${BASE} == "scratch" ]]; then
		if container_exists "${NAME}"; then
			info_log "using exists container '${NAME}'."
			container_get_id "${NAME}"
		else
			info_log "container '${NAME}' not exists, create from scratch."
			new_container "${NAME}" "scratch"
		fi
	else
		if ! image_exists "${BASE}"; then
			info_log "missing base image ${BASE}, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${BASE}" >&2
		fi

		local EXISTS_CID GOT EXPECT
		EXISTS_CID=$(container_find_id "${NAME}")
		if [[ -n ${EXISTS_CID} ]]; then
			GOT=$(container_get_base_image_id "${EXISTS_CID}")
			EXPECT=$(image_get_id "${BASE}")
			if [[ ${EXPECT} == "${GOT}" ]]; then
				info_log "using exists container '${NAME}'."
				container_get_id "${NAME}"
			else
				info_log "not using exists container: ${BASE} is updated"
				info_log "    current image:          ${EXPECT}"
				info_log "    exists container based: ${GOT}"
				buildah rm "${NAME}" >/dev/null
				new_container "${NAME}" "${BASE}"
			fi
		else
			info_log "container '${NAME}' not exists, create from image ${BASE}."
			new_container "${NAME}" "${BASE}"
		fi
	fi
}
