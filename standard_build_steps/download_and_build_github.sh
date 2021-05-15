#!/usr/bin/env bash

function download_and_build_github() {
	# CACHE_BRANCH=qbittorrent-build
	# PROJ_ID="libtorrent"
	# REPO=arvidn/libtorrent
	# BRANCH=RC_1_2
	local -r PSTEP="${STEP:-}"
	local __FORCE=${BUILDAH_FORCE:-}
	BUILDAH_FORCE=''

	STEP="${PSTEP}（下载）"
	hash_download() {
		if [[ ! $BRANCH ]]; then
			BRANCH=$(http_get_github_default_branch_name "$REPO")
		fi
		http_get_github_last_commit_id_on_branch "$REPO" "$BRANCH"
	}
	do_download() {
		local MNT
		download_github "$REPO" "$BRANCH"
		MNT=$(buildah mount "$1")
		download_git_result_copy "$MNT/opt/projects/$PROJ_ID" "$REPO" "$BRANCH"
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

	unset -f hash_download do_download hash_compile do_compile
}
