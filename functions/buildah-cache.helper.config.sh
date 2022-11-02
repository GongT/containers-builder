#!/usr/bin/env bash

function buildah_config() {
	local NAME=$1 ARGS
	# local CHANGE_TIMESTAMP=yes
	if [[ -f $2 ]]; then
		mapfile -t ARGS <"$2"
	else
		shift
		ARGS=("$@")
	fi

	__buildah_config_hash() {
		echo "${ARGS[*]}"
	}
	__buildah_config_do() {
		xbuildah config "${ARGS[@]}" "$1"
	}
	buildah_cache2 "$NAME" __buildah_config_hash __buildah_config_do
}
