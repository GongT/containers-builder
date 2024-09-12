function install_build_result() {
	local -r CACHE_BRANCH=$1 SOURCE_IMAGE=$2
	shift
	shift
	local -ar PROJECT_IDS=("$@")

	_install_build_result_hash() {
		echo "${SOURCE_IMAGE}"
	}
	_install_build_result_copyfiles() {
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
	buildah_cache "${CACHE_BRANCH}" _install_build_result_hash _install_build_result_copyfiles
	unset -f _install_build_result_hash _install_build_result_copyfiles
}
