#!/usr/bin/env bash

if [[ "${__PRAGMA_ONCE_FUNCTIONS_SH+found}" = found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_SH=yes

set -Eeuo pipefail
shopt -s lastpipe

if [[ "${CONTAINERS_DATA_PATH+found}" != "found" ]]; then
	export CONTAINERS_DATA_PATH="/data/AppData"
fi
declare -xr CONTAINERS_DATA_PATH="${CONTAINERS_DATA_PATH}"
declare -xr COMMON_LIB_ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -xr MONO_ROOT_DIR="$(dirname "$COMMON_LIB_ROOT")"
declare -xr CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")" .sh)"

if [[ "${CURRENT_DIR+found}" != "found" ]]; then
	CURRENT_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[-1]}")")"
	if [[ "$CURRENT_DIR" == "." ]]; then
		echo "Error: can't get current script location." >&2
		exit 1
	fi
	if [[ "$(basename "${CURRENT_DIR}")" = "scripts" ]]; then
		CURRENT_DIR="$(dirname "${CURRENT_DIR}")"
	fi
fi
PROJECT_NAME="$(basename "${CURRENT_DIR}")"

if [[ "${SYSTEM_COMMON_CACHE+found}" != "found" ]]; then
	SYSTEM_COMMON_CACHE='/var/cache'
fi

declare -xr ANNOID_CACHE_PREV_STAGE="me.gongt.cache.prevstage"
declare -xr ANNOID_CACHE_HASH="me.gongt.cache.hash"
declare -xr LABELID_RESULT_HASH="me.gongt.hash"

# shellcheck source=./functions/fs.sh
source "$COMMON_LIB_ROOT/functions/fs.sh"
# shellcheck source=./functions/output.sh
source "$COMMON_LIB_ROOT/functions/output.sh"
# shellcheck source=./functions/arguments.sh
source "$COMMON_LIB_ROOT/functions/arguments.sh"
# shellcheck source=./functions/download_file.sh
source "$COMMON_LIB_ROOT/functions/download_file.sh"
# shellcheck source=./functions/ci.sh
source "$COMMON_LIB_ROOT/functions/ci.sh"
# shellcheck source=./functions/proxy.sh
source "$COMMON_LIB_ROOT/functions/proxy.sh"
