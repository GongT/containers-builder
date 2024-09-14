declare LAST_KNOWN_BASE=
function buildah_cache_start() {
	local BASE_IMG=$1

	if [[ ${BASE_IMG} == "fedora"* || ${BASE_IMG} == "fedora-minimal"* ]]; then
		if [[ ${BASE_IMG} == "fedora" || ${BASE_IMG} == "fedora-minimal" ]]; then
			BASE_IMG+=":${FEDORA_VERSION}"
		else
			info_warn "using Fedora with version tag: ${BASE_IMG}"
		fi
		BASE_IMG="registry.fedoraproject.org/${BASE_IMG}"
	fi

	info "start cache branch"
	if [[ ${BASE_IMG} == scratch ]]; then
		LAST_KNOWN_BASE=
		info_note "  - using empty base"
		BUILDAH_LAST_IMAGE="scratch"
		return
	fi

	BUILDAH_LAST_IMAGE=$(image_find_id "${BASE_IMG}")
	# if [[ -n ${BUILDAH_LAST_IMAGE} ]]; then
	# 	if is_ci; then
	# 		if [[ ${NO_PULL_BASE-no} != yes ]]; then
	# 			info_warn "  - skip pull base due to NO_PULL_BASE=${NO_PULL_BASE}"
	# 		else
	# 			control_ci group "[cache start] pull base image: ${BASE_IMG}"
	# 			xpodman image pull "${BASE_IMG}"
	# 			control_ci groupEnd
	# 		fi
	# 	fi

	# 	LAST_KNOWN_BASE=$(image_find_full_name "${BASE_IMG}")
	# 	info_note "  - using exists base: ${LAST_KNOWN_BASE} ($BUILDAH_LAST_IMAGE)"
	# 	return
	# fi

	info_note "  - using base not exists, pull it: ${BASE_IMG}"
	BUILDAH_LAST_IMAGE=$(xpodman image pull "${BASE_IMG}")
	LAST_KNOWN_BASE=$(image_find_full_name "${BUILDAH_LAST_IMAGE}")
}

# function _repo_query() {
# 	NAME=$1
# 	if [[ $1 == *:/* ]]; then
# 		local -r NAME="$1"
# 	else
# 		local -r NAME="docker://${NAME}"
# 	fi

# 	local -r CACHE_DIR="${SYSTEM_FAST_CACHE}/repo-query-cache/"
# 	mkdir -p "${CACHE_DIR}"

# 	local -r REF_FILE="${CACHE_DIR}/update"
# 	touch -d "7 days ago" "${REF_FILE}"

# 	local -r CACHE_FILE="${CACHE_DIR}/$(echo "${NAME}" | md5sum | awk '{print $1}').json"

# 	if [[ ! -e ${CACHE_FILE} ]] || [[ ${REF_FILE} -nt ${CACHE_FILE} ]]; then
# 		x skopeo inspect "${NAME}" | jq --raw-output >"${CACHE_FILE}"
# 	fi

# 	cat "${CACHE_FILE}"
# }

# function repo_query() {
# 	_repo_query "$1" >&2
# 	:
# }
