#!/usr/bin/env bash

function merge_local_fs() {
	local -r CACHE_BRANCH=$1 EXTRA_SCRIPT="${2:-}"
	if ! [[ "${STEP:-}" ]]; then
		STEP="复制文件"
	fi
	_hash_filesystem() {
		hash_path fs
		if [[ $EXTRA_SCRIPT ]]; then
			cat "$EXTRA_SCRIPT"
		fi
	}
	_copy_files() {
		buildah copy "$1" fs /
		if [[ $EXTRA_SCRIPT ]]; then
			if [[ "$(head -1 "$EXTRA_SCRIPT")" == *bash* ]]; then
				buildah run "$1" bash <"$EXTRA_SCRIPT"
			else
				buildah run "$1" sh <"$EXTRA_SCRIPT"
			fi
		fi
	}
	buildah_cache2 "$CACHE_BRANCH" _hash_filesystem _copy_files

	unset _hash_filesystem
	unset _copy_files
}
