#!/usr/bin/env bash

declare -a PACMAN_CACHE_ARGS
declare ARCH_PACMAN_CID

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
	info "update pacman cache"
	ARCH_PACMAN_CID=$(create_if_not "pacman" "docker.io/library/archlinux")
	local TMP_SCRIPT=$(create_temp_file "pacman.install.sh")

	{
		echo 'rm -f /var/lib/pacman/db.lck'
		if ! is_ci; then
			cat <<-'EOF'
				echo 'Server = http://mirrors.aliyun.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist 
			EOF
		fi
		echo "pacman --noconfirm -Syy"
	} >"${TMP_SCRIPT}"

	local WHO_AM_I="pacman:prepare"
	buildah_run_shell_script "${PACMAN_CACHE_ARGS[@]}" "${ARCH_PACMAN_CID}" "${TMP_SCRIPT}"
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

	buildah_cache_start "docker.io/library/archlinux"

	STEP="安装系统依赖:"
	___pacman_hash() {
		use_pacman_cache "archlinux_latest" >&2
		pacman_prepare_environment >&2

		RES=$(buildah "${PACMAN_CACHE_ARGS[@]}" run "${ARCH_PACMAN_CID}" "bash" "-cx" "${SEARCH}")
		RES=$(echo "${RES}" | grep -vE '^\s' | sed -E 's/\s+\[.+$//g')

		info_log "================================================="
		indent_multiline "${RES}"
		info_log "================================================="

		echo "${RES}"
	}
	___pacman_install() {
		buildah run "${PACMAN_CACHE_ARGS[@]}" "$1" "bash" "-c" "cat /etc/pacman.d/mirrorlist; exec pacman --noconfirm -Su ${DEPS[*]}"
	}
	buildah_cache "${NAME}" ___pacman_hash ___pacman_install

	unset -f ___pacman_install ___pacman_hash
}
