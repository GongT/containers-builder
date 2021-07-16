#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_SH=yes

set -Eeuo pipefail
shopt -s lastpipe

if [[ ${CONTAINERS_DATA_PATH+found} != "found" ]]; then
	export CONTAINERS_DATA_PATH="/data/AppData"
fi
declare -xr CONTAINERS_DATA_PATH="${CONTAINERS_DATA_PATH}"
declare -xr COMMON_LIB_ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

declare -xr MONO_ROOT_DIR="$(dirname "$COMMON_LIB_ROOT")"
if [[ -e "$MONO_ROOT_DIR/.env" ]]; then
	set -a
	source "$MONO_ROOT_DIR/.env"
	set +a
fi

declare -xr CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")" .sh)"

function find_current_file_absolute_path() {
	local D=$(pwd)
	while [[ $D != '/' ]]; do
		if [[ -e "$D/$CURRENT_FILE" ]]; then
			CURRENT_FILE=$(realpath "$D/$CURRENT_FILE")
			return
		fi
		D=$(dirname "$D")
	done
	D="$COMMON_LIB_ROOT"
	while [[ $D != '/' ]]; do
		if [[ -e "$D/$CURRENT_FILE" ]]; then
			CURRENT_FILE=$(realpath "$D/$CURRENT_FILE")
			return
		fi
		D=$(dirname "$D")
	done

	die "can not find absolute path of \$0($CURRENT_FILE), in:\n - $COMMON_LIB_ROOT\n - $(pwd)"
}

CURRENT_FILE="${BASH_SOURCE[-1]}"
if [[ $CURRENT_FILE != /* ]]; then
	find_current_file_absolute_path
else
	CURRENT_FILE=$(realpath "$CURRENT_FILE")
fi
if [[ ${CURRENT_DIR+found} != "found" ]]; then
	CURRENT_DIR="$(dirname "$CURRENT_FILE")"
	if [[ $CURRENT_DIR == "." ]]; then
		echo "Error: can't get current script location." >&2
		exit 1
	fi
	if [[ "$(basename "${CURRENT_DIR}")" == "scripts" ]]; then
		CURRENT_DIR="$(dirname "${CURRENT_DIR}")"
	fi
fi
if [[ ${PROJECT_NAME+found} != found ]]; then
	PROJECT_NAME="$(basename "${CURRENT_DIR}")"
fi
declare -r PROJECT_NAME

if [[ ${SYSTEM_COMMON_CACHE+found} != "found" ]]; then
	SYSTEM_COMMON_CACHE='/var/cache'
fi
if [[ ${SYSTEM_FAST_CACHE+found} != "found" ]]; then
	SYSTEM_FAST_CACHE="$SYSTEM_COMMON_CACHE"
fi

declare -xr ANNOID_CACHE_PREV_STAGE="me.gongt.cache.prevstage"
declare -xr ANNOID_CACHE_HASH="me.gongt.cache.hash"
declare -xr LABELID_RESULT_HASH="me.gongt.hash"

declare -a EXIT_HANDLERS=()
function register_exit_handler() {
	EXIT_HANDLERS+=("$@")
}
function _exit() {
	local EXIT_CODE=$?
	set +Eeuo pipefail
	local CB
	for CB in "${EXIT_HANDLERS[@]}"; do
		echo -e "\e[2m ! $CB\e[0m" >&2
		"$CB"
	done
	exit $EXIT_CODE
}

trap _exit EXIT

if [[ ${REGISTRY_AUTH_FILE+found} != "found" ]]; then
	export REGISTRY_AUTH_FILE="/etc/containers/auth.json"
fi

# shellcheck source=./functions/fs.sh
source "$COMMON_LIB_ROOT/functions/fs.sh"
# shellcheck source=./functions/output.sh
source "$COMMON_LIB_ROOT/functions/output.sh"
# shellcheck source=./functions/arguments.sh
source "$COMMON_LIB_ROOT/functions/arguments.sh"
# shellcheck source=./functions/download_file.sh
source "$COMMON_LIB_ROOT/functions/download_file.sh"
# shellcheck source=./functions/platform.sh
source "$COMMON_LIB_ROOT/functions/platform.sh"
# shellcheck source=./functions/proxy.sh
source "$COMMON_LIB_ROOT/functions/proxy.sh"
# shellcheck source=./functions/temp.sh
source "$COMMON_LIB_ROOT/functions/temp.sh"
# shellcheck source=./functions/strings.sh
source "$COMMON_LIB_ROOT/functions/strings.sh"
