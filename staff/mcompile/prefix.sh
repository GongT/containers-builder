#!/usr/bin/env bash

set -Eeuo pipefail

declare -xr SOURCE="/opt/projects/$PROJECT_ID"
declare -xr ARTIFACT_PREFIX="/opt/dist"
declare -xr PREFIX="$ARTIFACT_PREFIX"

cd "$SOURCE"
mkdir -p "$ARTIFACT_PREFIX"

if command -v ccache &>/dev/null; then
	export CCACHE_DIR="$SYSTEM_FAST_CACHE/CCACHE"
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

	echo "Using CCACHE. ($(command -v gcc)) @ $CCACHE_DIR"
else
	echo "NOT using CCACHE."
fi

function group() {
	if is_ci; then
		echo "::group::$*"
	else
		echo -e "\e[38;5;14m$*\e[0m"
	fi
}

function groupEnd() {
	if is_ci; then
		echo "::endgroup::"
	fi
}

function x() {
	echo -e " + $*" >&2
	"$@"
}
