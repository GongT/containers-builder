#!/usr/bin/env bash

set -Eeuo pipefail

export INSTALL_TARGET="/mnt/install"
export INSTALL_SOURCE="/opt/dist"
mkdir -p "$INSTALL_SOURCE"
cd "$INSTALL_SOURCE"

declare -rx LIST_FILE=$(mktemp -u)

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
			find "${INSTALL_SOURCE}${I}" -type f >>"$TMP"
		fi
	done
	mapfile -t BINS <"$TMP"
	rm -f "$TMP"

	for I in "${BINS[@]}"; do
		echo -e "\e[2m * $I\e[0m"
	done

	collect_binary_dependencies "${BINS[@]}"
}
function copy_dist_root() {
	# old name
	collect_dist_root
}
function collect_dist_root() {
	info_log "Copy all files from $INSTALL_SOURCE to $INSTALL_TARGET"
	find "$INSTALL_SOURCE" -type f >>"$LIST_FILE"
}

function copy_collected_dependencies() {
	# old name
	copy_collected_files
}
function copy_collected_files() {
	if ! [[ -e $LIST_FILE ]]; then
		info_log "no collected dependencies..."
		return
	fi

	local DATA
	DATA=$(sed "#$INSTALL_TARGET/#d" "$LIST_FILE")
	echo "$DATA" | sort | uniq >"$LIST_FILE"

	info_log "====================== Copy dependencies to $INSTALL_SOURCE"
	echo -e '\e[2m' >&2
	tar --create "--directory=/" "--files-from=$LIST_FILE" \
		--transform="s,^${INSTALL_SOURCE/\//}/,,g" \
		| tar --verbose --skip-old-files --extract \
			--keep-directory-symlink \
			"--directory=$INSTALL_TARGET"
	echo -e '\e[0m' >&2
	info_log "======================"
}

function collect_with_all_links() {
	local L="$1"
	collect_system_file "$L"

	if ! [[ -L $L ]]; then
		return
	fi

	local DIR
	DIR=$(dirname "$L")
	L=$(realpath --no-symlinks "$DIR/$(readlink "$L")")

	collect_with_all_links "$L"
}

function collect_system_file() {
	local FILE="$1"
	if [[ $FILE != "$INSTALL_TARGET/"* ]]; then
		echo "$FILE" >>"$LIST_FILE"
	else
		echo -e "\e[2mSkip cross-filesystem file: $FILE\e[0m" >&2
	fi
}

function collect_binary_dependencies() {
	local BIN FILE

	for BIN; do
		BIN=$(realpath "$BIN")
		if ! [[ -e $BIN ]]; then
			echo "missing required binary: $BIN"
			exit 1
		fi

		collect_system_file "$BIN"
		# Name only .so files (common)
		mapfile -t FILES < <(ldd "$BIN" | grep '=>' | awk '{print $3}')
		for FILE in "${FILES[@]}"; do
			if [[ $FILE == not ]]; then
				ldd "$BIN" >&2
				echo "Failed to resolve some dependencies of $BIN." >&2
				exit 1
			fi
			collect_with_all_links "$FILE"
		done

		# Absolute .so files (rare)
		for FILE in $(ldd "$BIN" | grep -v '=>' | awk '{print $1}'); do
			if [[ $FILE =~ linux-vdso* ]]; then
				continue
			fi
			collect_with_all_links "$FILE"
		done
	done
}
