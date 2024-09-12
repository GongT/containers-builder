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

	if [[ -z ${STEP-} ]]; then
		STEP="复制文件"
	fi
	___merge_local_fs_hash() {
		hash_path fs
		if [[ -n ${EXTRA_SCRIPT} ]]; then
			printf "\0\0\0\0"
			cat "${EXTRA_SCRIPT}"
		fi
	}
	___merge_local_fs_make() {
		buildah copy "$1" fs /
		local SH=bash
		if [[ -n ${EXTRA_SCRIPT} ]]; then
			local EXTRA_SCRIPT_ABS=$(realpath "${EXTRA_SCRIPT}")
			local WHO_AM_I="${EXTRA_SCRIPT}"
			buildah_run_shell_script "${ARGS[@]}" "$1" "${EXTRA_SCRIPT_ABS}"
		fi
	}
	buildah_cache "${CACHE_BRANCH}" ___merge_local_fs_hash ___merge_local_fs_make

	unset -f ___merge_local_fs_hash ___merge_local_fs_make
}
