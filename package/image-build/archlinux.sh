#!/usr/bin/env bash

declare -r ARCHLINUX_VERSION=latest

function use_pacman_cache() {
	local -r SYSTEM="${1:-archlinux}"
	info_log "using ${SYSTEM} pacman cache: ${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/packages"
	mkdir -p "${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/packages" "${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/lists"
	echo "--volume=${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/packages:/var/cache/pacman"
	echo "--volume=${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/lists:/var/lib/pacman/sync"
}

function make_base_image_by_pacman() {
	local NAME=$1 STEP=() DEPS=()
	shift

	if [[ -e $1 ]]; then
		read_list_file "$1" DEPS
		shift
	else
		DEPS=("$@")
	fi

	BUILDAH_LAST_IMAGE="archlinux:${ARCHLINUX_VERSION}"

	STEP="安装系统依赖:"
	pacman_hash() {
		echo "${DEPS[*]}"
	}
	pacman_install() {
		buildah run $(use_pacman_cache) "$1" "bash" "-c" "pacman --noconfirm -Syu ${DEPS[*]}"
	}
	buildah_cache2 "${NAME}" pacman_hash pacman_install
}
