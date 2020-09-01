#!/usr/bin/env bash

if [[ "${__PRAGMA_ONCE_FUNCTIONS_BUILD_SH+found}" = found ]]; then
	return
fi
declare -rx __PRAGMA_ONCE_FUNCTIONS_BUILD_SH=yes

# shellcheck source=./functions.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

BUILDAH="$(find_command buildah)"
declare -rx BUILDAH

# shellcheck source=./functions/shared_projects.sh
source "$COMMON_LIB_ROOT/functions/shared_projects.sh"
# shellcheck source=./functions/mdnf.sh
source "$COMMON_LIB_ROOT/functions/mdnf.sh"
# shellcheck source=./functions/buildah-cache.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.sh"
# shellcheck source=./functions/buildah.hooks.sh
source "$COMMON_LIB_ROOT/functions/buildah.hooks.sh"
# shellcheck source=./functions/alpine.sh
source "$COMMON_LIB_ROOT/functions/alpine.sh"
# shellcheck source=./functions/build-folder-hash.sh
source "$COMMON_LIB_ROOT/functions/build-folder-hash.sh"

function create_if_not() {
	local NAME=$1 BASE=$2

	# if [[ "${CI+found}" = "found" ]]; then
	# 	echo "[CI] Create container '$NAME' from image '$BASE'." >&2
	# 	new_container "$NAME" "$BASE"
	# el
	if [[ "$BASE" = "scratch" ]]; then
		if container_exists "$NAME"; then
			echo "Using exists container '$NAME'." >&2
			buildah inspect --type container --format '{{.Container}}' "$NAME"
		else
			echo "Create container '$NAME' from image $BASE." >&2
			new_container "$NAME" "$BASE"
		fi
	elif [[ \
		$(buildah inspect --type container --format '{{.FromImageID}}' "$NAME" 2>&1) == \
		\
		$(buildah inspect --type image --format '{{.FromImageID}}' "$BASE" 2>&1) ]] \
			; then
		echo "Using exists container '$NAME'." >&2
		buildah inspect --type container --format '{{.Container}}' "$NAME"
	else
		echo "Create container '$NAME' from image '$BASE'." >&2
		new_container "$NAME" "$BASE"
	fi
}

function container_exists() {
	buildah inspect --type container --format '{{.FromImageID}}' "$1" &> /dev/null
}

function image_exists() {
	buildah inspect --type image --format '{{.FromImageID}}' "$1" &> /dev/null
}

function new_container() {
	local NAME=$1
	local EXISTS
	EXISTS=$(buildah inspect --type container --format '{{.Container}}' "$NAME" 2> /dev/null || true)
	if [[ -n "$EXISTS" ]]; then
		echo "Remove exists container '$EXISTS'" >&2
		buildah rm "$EXISTS" &> /dev/null
	fi
	local FROM="${2-scratch}"
	if [[ "$FROM" != scratch ]] && ! image_exists "$FROM"; then
		info_note "missing base image $FROM, pulling from registry (proxy=$http_proxy)..."
		buildah pull "$FROM"
	fi
	buildah from --pull-never --name "$NAME" "$FROM"
}

function SHELL_USE_PROXY() {
	echo "PROXY=$PROXY"
	# shellcheck disable=SC2016
	echo '
if [ -n "$PROXY" ]; then
	echo "using proxy: ${PROXY}..." >&2
	export http_proxy="$PROXY"
	export https_proxy="$PROXY"
fi
'
}

function buildah_run_perfer_proxy() {
	if [[ "${PROXY+found}" = "found" ]]; then
		http_proxy="$PROXY" https_proxy="$PROXY" HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY" buildah run "$@"
	else
		buildah run "$@"
	fi
}

function buildah_run_deny_proxy() {
	http_proxy='' https_proxy='' HTTP_PROXY='' HTTPS_PROXY='' buildah run "$@"
}
