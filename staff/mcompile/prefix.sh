#!/usr/bin/env bash

set -Eeo pipefail

export SOURCE="/opt/projects/$PROJECT_ID"
cd "$SOURCE"

export ARTIFACT_PREFIX="/opt/dist"
export PREFIX="$ARTIFACT_PREFIX"
export ARTIFACT="$ARTIFACT_PREFIX/usr/bin"

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
