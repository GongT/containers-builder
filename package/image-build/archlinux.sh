#!/usr/bin/env bash

declare -r ARCHLINUX_VERSION=latest
declare -a PACMAN_CACHE_ARGS

function use_pacman_cache() {
	local -r SYSTEM="$1"
	info_log "using ${SYSTEM} pacman cache: ${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/packages"
	mkdir -p "${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/packages" "${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/lists"

	PACMAN_CACHE_ARGS=(
		"--volume=${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/packages:/var/cache/pacman"
		"--volume=${SYSTEM_COMMON_CACHE}/pacman/${SYSTEM}/lists:/var/lib/pacman/sync"
	)
}

pacman_prepare_environment() {
	use_pacman_cache "archlinux_${ARCHLINUX_VERSION}"

	info "update pacman cache"
	local ARCH_PACMAN_CID
	ARCH_PACMAN_CID=$(create_if_not "pacman" "archlinux_${ARCHLINUX_VERSION}")
	buildah run "${PACMAN_CACHE_ARGS[@]}" "${ARCH_PACMAN_CID}" bash -c \
		"rm -f /var/lib/pacman/db.lck ; echo 'Server = http://mirrors.aliyun.com/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist ; pacman --noconfirm -Syy"
}

function fork_archlinux() {
	local NAME=$1 STEP=() DEPS=()
	shift

	if [[ -e $1 ]]; then
		read_list_file "$1" DEPS
		shift
	else
		DEPS=("$@")
	fi
	local SEARCH RES
	SEARCH=$(printf '|%s' "${DEPS[@]}")
	SEARCH="^(${SEARCH:1})$"
	SEARCH=$(printf 'pacman --noconfirm -Ss %q' "${SEARCH}")

	buildah_cache_start "archlinux:${ARCHLINUX_VERSION}"

	STEP="安装系统依赖:"
	___pacman_hash() {
		use_pacman_cache >&2

		RES=$(buildah "${PACMAN_CACHE_ARGS[@]}" run "${ARCH_PACMAN_CID}" "bash" "-cx" "${SEARCH}")
		RES=$(echo "${RES}" | grep -vE '^\s' | sed -E 's/\s+\[.+$//g')

		info_log "================================================="
		indent_multiline "${RES}"
		info_log "================================================="

		echo "${RES}"
	}
	___pacman_install() {
		buildah run "${PACMAN_CACHE_ARGS[@]}" "$1" "bash" "-c" "echo 'Server = http://mirrors.aliyun.com/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist ; cat /etc/pacman.d/mirrorlist ; pacman --noconfirm -Su ${DEPS[*]}"
	}
	buildah_cache "${NAME}" ___pacman_hash ___pacman_install

	unset -f ___pacman_install ___pacman_hash
}
