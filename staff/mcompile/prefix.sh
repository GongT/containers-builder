#!/usr/bin/env bash

set -Eeo pipefail

export SOURCE="/opt/projects/$PROJECT_ID"
cd "$SOURCE"

export ARTIFACT_PREFIX="/opt/dist"
export PREFIX="$ARTIFACT_PREFIX"
export ARTIFACT="$ARTIFACT_PREFIX/usr/bin"

mkdir -p "$ARTIFACT"

if command -v ccache &> /dev/null; then
	export CCACHE_DIR='/opt/cache'
	export CCACHE_BASEDIR="/opt/projects"
	export CCACHE_COMPRESS='yes'
	export CCACHE_PATH="$PATH"
	export PATH="/opt/ccache_bin:$PATH"

	ccache_bin=$(command -v ccache)

	rm -rf /opt/ccache_bin
	mkdir -p /opt/ccache_bin
	ln -s "$ccache_bin" /opt/ccache_bin/gcc
	ln -s "$ccache_bin" /opt/ccache_bin/g++
	ln -s "$ccache_bin" /opt/ccache_bin/cc
	ln -s "$ccache_bin" /opt/ccache_bin/c++

	echo "Using CCACHE. ($(command -v gcc))"
fi

function copy_binary_with_dependencies() {
	local BIN FILE
	local RESULT=()

	function with_all_links() {
		local L="$1"
		RESULT+=("$L")

		if ! [[ -L "$L" ]]; then
			return
		fi

		local DIR
		DIR=$(dirname "$L")
		L=$(realpath --no-symlinks "$DIR/$(readlink "$L")")

		with_all_links "$L"
	}

	for BIN; do
		BIN=$(realpath "$BIN")
		if ! [[ -e "$BIN" ]]; then
			echo "missing required binary: $BIN"
			exit 1
		fi

		RESULT+=("$BIN")
		# Name only .so files (common)
		for FILE in $(ldd "$BIN" | grep '=>' | awk '{print $3}'); do
			if [[ "$FILE" == not ]]; then
				ldd "$BIN"
				echo 'Failed to resolve some dependencies of nginx.' >&2
				exit 1
			fi
			with_all_links "$FILE"
		done

		# Absolute .so files (rare)
		for FILE in $(ldd "$BIN" | grep -v '=>' | awk '{print $1}'); do
			if [[ "$FILE" =~ linux-vdso* ]]; then
				continue
			fi
			with_all_links "$FILE"
		done
	done

	{
		for FILE in "${RESULT[@]}"; do
			echo "$FILE"
		done
	} > /tmp/bins.lst

	tar -c -C / --files-from /tmp/bins.lst | tar -x -v -C "$ARTIFACT_PREFIX"

	unset -f with_all_links
}
