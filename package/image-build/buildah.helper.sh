function create_if_not() {
	local NAME=$1 BASE=$2

	if is_ci; then
		info_log "[CI] Create container '${NAME}' from image '${BASE}'."
		new_container "${NAME}" "${BASE}"
	elif [[ ${BASE} == "scratch" ]]; then
		if container_exists "${NAME}"; then
			info_log "Using exists container '${NAME}'."
			container_get_id "${NAME}"
		else
			info_log "Container '${NAME}' not exists, create from image ${BASE}."
			new_container "${NAME}" "${BASE}"
		fi
	else
		if ! image_exists "${BASE}"; then
			info_note "missing base image ${BASE}, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "${BASE}" >&2
		fi

		local EXPECT GOT
		GOT=$(container_get_base_image_id "${NAME}")
		EXPECT=$(image_get_id "${BASE}")
		if [[ ${EXPECT} == "${GOT}" ]]; then
			info_log "Using exists container '${NAME}'."
			container_get_id "${NAME}"
		elif [[ -n ${GOT} ]]; then
			info_log "Not using exists container: ${BASE} is updated"
			info_log "    current image:          ${EXPECT}"
			info_log "    exists container based: ${GOT}"
			buildah rm "${NAME}" >/dev/null
			new_container "${NAME}" "${BASE}"
		else
			info_log "Container '${NAME}' not exists, create from image ${BASE}."
			new_container "${NAME}" "${BASE}"
		fi
	fi
}

function container_exists() {
	local ID X
	ID=$(container_get_id "$1")
	X=$?
	if [[ ${X} -eq 0 ]] && [[ ${ID} == "" ]]; then
		info_warn "inspect container $1 success, but nothing return"
		return 1
	fi
	return "${X}"
}

function image_exists() {
	"${BUILDAH}" inspect --type image "$1" &>/dev/null
}

function image_get_id() {
	local R
	R=$("${BUILDAH}" inspect --type image --format '{{.FromImageID}}' "$1" 2>/dev/null)
	digist_to_short "${R}"
}
function image_find_id() {
	local R
	R=$("${BUILDAH}" inspect --type image --format '{{.FromImageID}}' "$1" 2>/dev/null || true)
	digist_to_short "${R}"
}

function container_get_id() {
	local R
	R=$("${BUILDAH}" inspect --type container --format '{{.ContainerID}}' "$1" 2>/dev/null)
	digist_to_short "${R}"
}
function container_find_id() {
	local R
	R=$("${BUILDAH}" inspect --type container --format '{{.ContainerID}}' "$1" 2>/dev/null || true)
	digist_to_short "${R}"
}
function container_get_base_image_id() {
	local R
	R=$("${BUILDAH}" inspect --type container --format '{{.FromImageID}}' "$1" 2>/dev/null)
	digist_to_short "${R}"
}

function is_id_digist() {
	[[ $1 =~ ^[0-9a-fA-F]{64}$ ]] || [[ $1 =~ ^[0-9a-fA-F]{12}$ ]]
}
function digist_to_short() {
	if [[ $1 =~ ^[0-9a-fA-F]{64}$ ]]; then
		echo "${1:0:12}"
	else
		echo "$1"
	fi
}

function new_container() {
	local NAME=$1
	local EXISTS
	EXISTS=$(container_get_id "${NAME}" || true)
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
