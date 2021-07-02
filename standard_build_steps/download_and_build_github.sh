#!/usr/bin/env bash

function download_and_build_github() {
	local -r CACHE_BRANCH=$1 PROJ_ID=$2 REPO=$3
	local BRANCH=${4:-}
	if [[ ! $BRANCH ]]; then
		BRANCH=$(http_get_github_default_branch_name "$REPO")
	fi

	local -r PSTEP="${STEP:-}"
	local __FORCE=${BUILDAH_FORCE:-}

	BUILDAH_FORCE=''
	STEP="${PSTEP}（下载）"
	hash_download() {
		download_github "$REPO" "$BRANCH"
	}
	do_download() {
		local MNT
		MNT=$(create_temp_dir "git-$PROJ_ID-$BRANCH")
		download_git_result_copy "$MNT" "$REPO" "$BRANCH"
		buildah copy "$1" "$MNT" "/opt/projects/$PROJ_ID"
	}
	buildah_cache2 "$CACHE_BRANCH" hash_download do_download

	BUILDAH_FORCE="$__FORCE"
	STEP="${PSTEP}（编译）"
	hash_compile() {
		cat "scripts/build-$PROJ_ID.sh"
	}
	do_compile() {
		SOURCE_DIRECTORY=no run_compile "$PROJ_ID" "$1" "./scripts/build-$PROJ_ID.sh"
		info "$PROJ_ID build complete..."
	}
	buildah_cache2 "$CACHE_BRANCH" hash_compile do_compile

	unset -f hash_download do_download hash_compile do_compile BUILDAH_FORCE STEP
}
