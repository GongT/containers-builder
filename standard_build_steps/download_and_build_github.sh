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

function download_and_build_github_release() {
	local -r CACHE_BRANCH=$1 PROJ_ID=$2 REPO=$3

	local RELEASE_URL=""
	local RELEASE_NAME=""

	hash_bitcoind() {
		http_get_github_release_id "$REPO"
		RELEASE_URL=$(echo "$LAST_GITHUB_RELEASE_JSON" | jq -r '.tarball_url')
		info_note "       * RELEASE_URL=$RELEASE_URL"
		RELEASE_NAME=$(echo "$LAST_GITHUB_RELEASE_JSON" | jq -r '.tag_name')
		info_note "       * RELEASE_NAME=$RELEASE_NAME"
	}
	compile_bitcoind() {
		local RESULT DOWNLOADED VERSION FILE_NAME="bitcoin.$RELEASE_NAME.tar.gz"
		DOWNLOADED=$(download_file "$RELEASE_URL" "$FILE_NAME")
		SOURCE_DIRECTORY="$(pwd)/source/bitcoin"
		rm -rf "$SOURCE_DIRECTORY"
		extract_tar "$DOWNLOADED" "1" "$SOURCE_DIRECTORY"

		RESULT=$(new_container "$1" "$BUILDAH_LAST_IMAGE")
		run_compile "bitcoin" "$RESULT" "source/builder.sh"
	}
	buildah_cache "btc-build" hash_bitcoind compile_bitcoind
}
