#!/usr/bin/env bash

# buildah_cache2
function buildah_cache2() {
	local -r NAME=$1 HASH_CALLBACK=$2 BUILD_CALLBACK=$3

	_hash_cb() {
		echo "$BUILDAH_LAST_IMAGE"
		"$HASH_CALLBACK"
		# echo "===========================================" >&2
		# cat "$TMPF" >&2
		# echo "===========================================" >&2
	}
	_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "$BUILDAH_LAST_IMAGE")
		"$BUILD_CALLBACK" "$CONTAINER"
	}

	buildah_cache "$NAME" _hash_cb _build_cb

	unset -f _hash_cb _build_cb
}
