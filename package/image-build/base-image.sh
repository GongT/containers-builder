declare LAST_KNOWN_BASE=
function buildah_cache_start() {
	local BASE_IMG=$1
	local RESULT_ID BASE_NAME

	if [[ ${BASE_IMG} == "fedora"* || ${BASE_IMG} == "fedora-minimal"* ]]; then
		BASE_IMG="registry.fedoraproject.org/${BASE_IMG}"
	fi
	if [[ ${BASE_IMG} == "registry.fedoraproject.org/fedora" || ${BASE_IMG} == "registry.fedoraproject.org/fedora-minimal" ]]; then
		BASE_IMG+=":${FEDORA_VERSION}"
	fi

	info_success "\nCache Branch Start"
	if [[ ${BASE_IMG} == scratch ]]; then
		LAST_KNOWN_BASE=
		info_note "  - using empty base"
		record_last_image "scratch"
		return
	fi

	RESULT_ID=$(image_find_digist "${BASE_IMG}")
	if [[ -n ${RESULT_ID} ]]; then
		if is_ci; then
			if [[ ${NO_PULL_BASE-} == yes ]]; then
				info_warn "  - skip pull base due to NO_PULL_BASE=${NO_PULL_BASE-}"
			else
				control_ci group "[cache start] pull base image: ${BASE_IMG}"
				xpodman image pull "${BASE_IMG}"
				control_ci groupEnd
			fi
		fi

		info_note "  - using exists base: $RESULT_ID"
	else
		info_note "  - using base not exists, pull it: ${BASE_IMG}"
		RESULT_ID=$(xpodman image pull "${BASE_IMG}")
	fi

	record_last_image "${RESULT_ID}"

	BASE_NAME=$(image_find_full_name "${RESULT_ID}")
	record_last_base_name "${BASE_NAME}"
	info_note "  - full name: ${BASE_NAME}"
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
