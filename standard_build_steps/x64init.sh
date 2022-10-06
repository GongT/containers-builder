#!/usr/bin/env bash

function download_and_install_x64_init() {
	STEP="下载init"
	CACHE_BRANCH=$1
	REPO=GongT/init
	RELEASE_URL=
	_hash_init() {
		http_get_github_release_id "$REPO"
		RELEASE_URL=$(github_release_asset_download_url linux_amd64)
	}
	_download_init() {
		local TGT=$1 DOWNLOADED FILE_NAME="gongt-init"
		DOWNLOADED=$(FORCE_DOWNLOAD=yes download_file "$RELEASE_URL" "$FILE_NAME")
		buildah copy "$TGT" "$DOWNLOADED" "/usr/sbin/init"
		buildah run "$TGT" chmod 0777 "/usr/sbin/init"
		buildah config --cmd "/usr/sbin/init" --stop-signal SIGINT "$TGT"
	}
	buildah_cache2 "$CACHE_BRANCH" _hash_init _download_init

	unset CACHE_BRANCH STEP REPO RELEASE_URL _hash_init _download_init
}
