#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

export PROJECT_NAME="simple-build"
source ../functions-build.sh

guard_no_root

podman images | (grep -E '<none>|cache|localhost' || true) | awk '{print $3}' | xargs --no-run-if-empty podman rmi

if [[ $CACHE_CENTER_TYPE == 'filesystem' ]]; then
	FILEPATH="${CACHE_CENTER_URL_BASE#*:}"
	if [[ -d $FILEPATH ]]; then
		info_warn "empty folder: $FILEPATH"
		for I in "$FILEPATH"/*/; do
			x rm -rf "$I"
		done
	fi
fi
