#!/usr/bin/env bash

# 合并 "fs" 目录到容器根目录里
# eg:
# 	merge_local_fs "ccc"
#
# 可以带一个后处理脚本:
#   merge_local_fs "ccc" --env=a=b --volume=a:b ./scripts/install.sh
# 此脚本存在于主机上，不需要随着fs目录一起复制
#
function merge_local_fs() {
	local -r CACHE_BRANCH=$1
	shift

	local ARGS=() POST_SCRIPT=
	while [[ $# -gt 0 ]]; do
		if [[ $1 == -* ]]; then
			ARGS+=("$1")
			shift
		else
			POST_SCRIPT="$1"
			shift
			if [[ $# -gt 0 ]]; then
				die "未知额外参数: $*"
			fi
		fi
	done
	if [[ ${#ARGS[@]} -gt 0 && -z ${POST_SCRIPT} ]]; then
		die "带有参数的情况下必须指定后处理脚本"
	fi

	if [[ -z ${STEP-} ]]; then
		STEP="复制文件"
	fi
	___merge_local_fs_hash() {
		hash_path fs
		if [[ -n ${POST_SCRIPT} ]]; then
			printf "%s\n" "${ARGS[@]}"
			printf "~~~~\n"
			cat "${POST_SCRIPT}"
		fi
	}
	___merge_local_fs_make() {
		buildah copy "$1" fs /
		if [[ -n ${POST_SCRIPT} ]]; then
			local TMPF
			TMPF=$(create_temp_file "merge-fs-post.sh")
			construct_child_shell_script "${TMPF}" "${POST_SCRIPT}"
			buildah_run_shell_script "$1" "${TMPF}" "${ARGS[@]}"
		fi
		buildah run "$1" /usr/bin/sh -c "find /bin /usr/bin /usr/local/bin -maxdepth 1 -mindepth 1 -exec chmod a+x {} \;"
	}
	buildah_cache "${CACHE_BRANCH}" ___merge_local_fs_hash ___merge_local_fs_make

	unset STEP
	unset -f ___merge_local_fs_hash ___merge_local_fs_make
}
