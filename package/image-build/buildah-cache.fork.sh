#!/usr/bin/env bash

function buildah_cache_fork() {
	guard_root_only
	local -r NAME=$1
	shift
	local -r NEW_BASE=$1
	shift
	local -r HASH_CALLBACK=$1
	shift
	local -r BUILD_CALLBACK=$1

	local -r FROM_IMAGE="${BUILDAH_LAST_IMAGE}"
	buildah_cache_start "${NEW_BASE}"

	_hash_bcf_cb() {
		echo "base: ${BUILDAH_LAST_IMAGE}"
		echo "from: ${FROM_IMAGE}"
		"${HASH_CALLBACK}"
	}
	_build_bcf_cb() {
		local SOURCE TARGET MNT
		SOURCE=$(new_container "${NAME}-fork-from" "${FROM_IMAGE}")

		TARGET=$(new_container "$1" "${BUILDAH_LAST_IMAGE}")
		MNT=$(buildah mount "${TARGET}")

		"${BUILD_CALLBACK}" "${SOURCE}" "${TARGET}" "${MNT}"
	}

	buildah_cache "${NAME}" _hash_bcf_cb _build_bcf_cb

	unset -f _hash_bcf_cb _build_bcf_cb
}

function buildah_cache_fork_script() {
	local -r NAME=$1
	shift
	local -r NEW_BASE=$1
	shift
	local -r BUILD_SCRIPT=$1
	shift
	local -ar BARGS=("$@")

	_hash_cfs_cb() {
		echo "script: ${BUILD_SCRIPT}"
		echo "args: ${BARGS[*]}"
	}
	_build_cfs_cb() {
		{
			SHELL_SCRIPT_PREFIX
			SHELL_USE_PROXY
			echo "declare -rx DIST_FOLDER=/mnt/dist"
			cat "${BUILD_SCRIPT}"
		} | buildah run "--volume=${MNT}:/mnt/dist" "${SOURCE}" bash -s - "${BARGS[@]}"
	}

	buildah_cache_fork "${NAME}" "${NEW_BASE}" _hash_cfs_cb _build_cfs_cb

	unset -f _hash_cfs_cb _build_cfs_cb
}
