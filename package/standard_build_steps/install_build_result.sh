function install_build_result() {
	local -r CACHE_BRANCH=$1 SOURCE_IMAGE=$2
	shift
	shift
	local -ar PROJECT_IDS=("$@")

	_hash() {
		echo "${SOURCE_IMAGE}"
	}
	_copy_files() {
		local PROJECT_ID
		for PROJECT_ID in "${PROJECT_IDS[@]}"; do
			local F="scripts/install-${PROJECT_ID}.sh"
			if [[ -e ${F} ]]; then
				run_install "${SOURCE_IMAGE}" "$1" "${PROJECT_ID}" "${F}"
			else
				run_install "${SOURCE_IMAGE}" "$1" "${PROJECT_ID}"
			fi
		done
	}
	buildah_cache2 "${CACHE_BRANCH}" _hash _copy_files
}
