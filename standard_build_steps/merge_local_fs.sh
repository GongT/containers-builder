#!/usr/bin/env bash

# merge "fs" folder to cache
# eg:
# 	merge_local_fs "ccc"
#  
# with extra bash script:
#   merge_local_fs "ccc" --env=a=b --volume=a:b ./scripts/install.sh
function merge_local_fs() {
	local -r CACHE_BRANCH=$1
	shift

	local ARGS=() EXTRA_SCRIPT=
	while [[ $# -gt 0 ]]; do
		if [[ $1 == -* ]]; then
			ARGS+=("$1")
			shift
		else
			EXTRA_SCRIPT="$1"
			shift
			if [[ $# -gt 0 ]]; then
				die "invalid extra arguments: $*"
			fi
		fi
	done

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
				buildah run "${ARGS[@]}" "$1" bash <"$EXTRA_SCRIPT"
			else
				buildah run "${ARGS[@]}" "$1" sh <"$EXTRA_SCRIPT"
			fi
		fi
	}
	buildah_cache2 "$CACHE_BRANCH" _hash_filesystem _copy_files

	unset _hash_filesystem
	unset _copy_files
}
