#!/usr/bin/env bash

function setup_systemd() {
	local STEP="配置镜像中的systemd"
	local CACHE_BRANCH="$1"
	local __hash_cb __build_cb

	function __hash_cb() {
		echo "version:2"
		hash_path "$COMMON_LIB_ROOT/staff/systemd-filesystem"
	}
	function __build_cb() {
		local C="$1"
		buildah copy "$C" "$COMMON_LIB_ROOT/staff/systemd-filesystem/*" "/"
		buildah config '--entrypoint=["/entrypoint/entrypoint.sh"]' '--cmd=["--systemd"]' "$C"
		buildah run "$C" bash <"$COMMON_LIB_ROOT/staff/systemd-filesystem/setup.sh"
	}
	buildah_cache2 "$CACHE_BRANCH" __hash_cb __build_cb
}
