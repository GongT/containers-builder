#!/usr/bin/env bash

### this file execute inside container

declare -rx INSTALL_TARGET="/mnt/install"
declare -rx INSTALL_SOURCE="/opt/dist"
mkdir -p "${INSTALL_SOURCE}"
cd "${INSTALL_SOURCE}"

export __INSTALL_LIST_FILE=$(mktemp)

function info_log() {
	{
		echo -ne "    \e[38;5;13m"
		echo -n "$*"
		echo -e "\e[0m"
	} >&2
}

function collect_dist_binary_dependencies() {
	info_log "Checking binary dependencies"
	local BINS=() IFS=$'\n' I TMP
	TMP=$(mktemp)
	for I in /bin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /usr/libexec /usr/local/libexec "$@"; do
		if [[ -d "${INSTALL_SOURCE}${I}" ]]; then
			find "${INSTALL_SOURCE}${I}" -type f >>"${TMP}"
		fi
	done
	mapfile -t BINS <"${TMP}"
	rm -f "${TMP}"

	collect_binary_dependencies "${BINS[@]}"
}
function collect_dist_root() {
	info_log "Collect all files from ${INSTALL_SOURCE} to ${INSTALL_TARGET}"
	local LIST FILE
	mapfile -t LIST < <(find "${INSTALL_SOURCE}" -type f)
	for FILE in "${LIST[@]}"; do
		if ! grep -Fxq "${FILE}" "${__INSTALL_LIST_FILE}"; then
			echo -e "\e[2m      * ${FILE}\e[0m" >&2
			echo "${FILE}" >>"${__INSTALL_LIST_FILE}"
		fi
	done
}
function copy_collected_files() {
	if [[ ! -e ${__INSTALL_LIST_FILE} ]]; then
		info_log "no collected dependencies..."
		return
	fi

	local UNI_LIST_FILE=$(mktemp -u)
	sort <"${__INSTALL_LIST_FILE}" | uniq >"${UNI_LIST_FILE}"

	info_log "====================== Copy dependencies to ${INSTALL_SOURCE}"
	echo -e '\e[2m' >&2
	tar --create \
		-f /tmp/filesystem.tar \
		--ignore-failed-read \
		--ignore-command-error \
		"--directory=/" \
		"--files-from=${UNI_LIST_FILE}" \
		--owner=0 --group=0 \
		--transform="s,^${INSTALL_SOURCE/\//}/,,g"

	cp -f /tmp/filesystem.tar "${INSTALL_TARGET}"
	# tar --skip-old-files \
	# 	--extract \
	# 	-f /tmp/filesystem.tar \
	# 	--keep-directory-symlink \
	# 	--no-same-owner --no-same-permissions \
	# 	"--directory=$INSTALL_TARGET"
	echo -e '\e[0m' >&2
	info_log "======================"
}

function collect_with_all_links() {
	local L="$1"
	collect_system_file "${L}"

	if [[ ! -L ${L} ]]; then
		return
	fi

	local DIR
	DIR=$(dirname "${L}")
	L=$(realpath --no-symlinks "${DIR}/$(readlink "${L}")")

	collect_with_all_links "${L}"
}

function collect_system_file() {
	local FILE
	for FILE; do
		if [[ ${FILE} != "${INSTALL_TARGET}/"* ]]; then
			echo -e "\e[2m      * ${FILE}\e[0m" >&2
			echo "${FILE}" >>"${__INSTALL_LIST_FILE}"
		else
			echo -e "\e[38;5;11mSkip cross-filesystem file: ${FILE}\e[0m" >&2
		fi
	done
}

function collect_binary_dependencies() {
	local BIN FILE

	for BIN; do
		BIN=$(realpath "${BIN}")
		if [[ ! -e ${BIN} ]]; then
			echo "missing required binary: ${BIN}"
			exit 1
		fi

		echo -e "\e[2m      binary: ${BIN}\e[0m"
		collect_system_file "${BIN}"
		# Name only .so files (common)
		mapfile -t FILES < <(ldd "${BIN}" | grep '=>' | awk '{print $3}')
		for FILE in "${FILES[@]}"; do
			if [[ ${FILE} == not ]]; then
				ldd "${BIN}" >&2
				echo "Failed to resolve some dependencies of ${BIN}." >&2
				exit 1
			fi
			collect_with_all_links "${FILE}"
		done

		# Absolute .so files (rare)
		for FILE in $(ldd "${BIN}" | grep -v '=>' | awk '{print $1}'); do
			if [[ ${FILE} =~ linux-vdso* ]]; then
				continue
			fi
			collect_with_all_links "${FILE}"
		done
	done
}

install_main
