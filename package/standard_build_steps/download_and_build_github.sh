#!/usr/bin/env bash

function download_and_build_github() {
	local -r CACHE_BRANCH=$1 PROJ_ID=$2 REPO=$3
	local BRANCH=${4:-}
	if [[ -z ${BRANCH} ]]; then
		BRANCH=$(http_get_github_default_branch_name "${REPO}")
	fi

	local -r PSTEP="${STEP:-}"
	local __FORCE=${BUILDAH_FORCE:-}

	BUILDAH_FORCE=''
	STEP="${PSTEP}（下载）"
	hash_download() {
		http_get_github_last_commit_id_on_branch "${REPO}" "${BRANCH}"
	}
	do_download() {
		local MNT
		MNT=$(create_temp_dir "git-${PROJ_ID}-${BRANCH}")

		download_github "${REPO}" "${BRANCH}"
		download_git_result_copy "${MNT}" "${REPO}" "${BRANCH}"

		buildah copy "$1" "${MNT}" "/opt/projects/${PROJ_ID}"
	}
	buildah_cache "${CACHE_BRANCH}" hash_download do_download

	BUILDAH_FORCE="${__FORCE}"
	STEP="${PSTEP}（编译）"
	hash_compile() {
		cat "scripts/build-${PROJ_ID}.sh"
	}
	do_compile() {
		SOURCE_DIRECTORY=no run_compile "${PROJ_ID}" "$1" "./scripts/build-${PROJ_ID}.sh"
		info "${PROJ_ID} build complete..."
	}
	buildah_cache "${CACHE_BRANCH}" hash_compile do_compile

	unset -f hash_download do_download hash_compile do_compile BUILDAH_FORCE STEP
}

function download_and_build_github_release() {
	local -r CACHE_BRANCH=$1 PROJ_ID=$2 REPO=$3

	local -r PSTEP="${STEP:-}"
	local __FORCE=${BUILDAH_FORCE:-}

	BUILDAH_FORCE=''
	STEP="${PSTEP}（下载）"

	local RELEASE_URL=""
	local RELEASE_NAME=""
	hash_last_release() {
		http_get_github_release "${REPO}"
		RELEASE_URL=$(echo "${LAST_GITHUB_RELEASE_JSON}" | jq -r '.tarball_url')
		info_note "       * RELEASE_URL=${RELEASE_URL}"
		RELEASE_NAME=$(echo "${LAST_GITHUB_RELEASE_JSON}" | jq -r '.tag_name')
		info_note "       * RELEASE_NAME=${RELEASE_NAME}"

		echo "${RELEASE_URL} | ${RELEASE_NAME}"
	}
	download_last_release() {
		local DOWNLOADED SOURCE_DIRECTORY FILE_NAME="${PROJ_ID}.${RELEASE_NAME}.tar.gz"
		DOWNLOADED=$(download_file "${RELEASE_URL}" "${FILE_NAME}")
		SOURCE_DIRECTORY="$(create_temp_dir "src.${PROJ_ID}")"
		extract_tar "${DOWNLOADED}" "1" "${SOURCE_DIRECTORY}"

		buildah copy "$1" "${SOURCE_DIRECTORY}" "/opt/projects/${PROJ_ID}"
	}
	buildah_cache "${CACHE_BRANCH}" hash_last_release download_last_release

	BUILDAH_FORCE="${__FORCE}"
	STEP="${PSTEP}（编译）"
	hash_compile() {
		cat "scripts/build-${PROJ_ID}.sh"
	}
	do_compile() {
		SOURCE_DIRECTORY=no run_compile "${PROJ_ID}" "$1" "./scripts/build-${PROJ_ID}.sh"
	}
	buildah_cache "${CACHE_BRANCH}" hash_compile do_compile

	unset -f hash_last_release download_last_release hash_compile do_compile BUILDAH_FORCE STEP
}
