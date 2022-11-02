#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_BUILD_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_BUILD_SH=yes

# shellcheck source=./functions.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

BUILDAH="$(find_command buildah)"
declare -rx BUILDAH

declare -r FEDORA_SYSTEMD_COMMAND='/lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=no systemd.journald.forward_to_console=yes'

# shellcheck source=./functions/mdnf.sh
source "$COMMON_LIB_ROOT/functions/mdnf.sh"
# shellcheck source=./functions/mcompile.sh
source "$COMMON_LIB_ROOT/functions/mcompile.sh"
# shellcheck source=./functions/buildah-cache.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.sh"
# shellcheck source=./functions/build-folder-hash.sh
source "$COMMON_LIB_ROOT/functions/build-folder-hash.sh"
# shellcheck source=./functions/buildah-cache.2.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.2.sh"
# shellcheck source=./functions/buildah-cache.fork.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.fork.sh"
# shellcheck source=./functions/buildah-cache.helper.config.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.helper.config.sh"
# shellcheck source=./functions/buildah-cache.helper.run.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.helper.run.sh"
# shellcheck source=./functions/buildah-cache.remote.sh
source "$COMMON_LIB_ROOT/functions/buildah-cache.remote.sh"
# shellcheck source=./functions/buildah.hooks.sh
source "$COMMON_LIB_ROOT/functions/buildah.hooks.sh"
# shellcheck source=./functions/alpine.sh
source "$COMMON_LIB_ROOT/functions/alpine.sh"
# shellcheck source=./functions/apt-get.sh
source "$COMMON_LIB_ROOT/functions/apt-get.sh"
# shellcheck source=./functions/python.sh
source "$COMMON_LIB_ROOT/functions/python.sh"
# shellcheck source=./functions/build-folder-hash.sh
source "$COMMON_LIB_ROOT/functions/build-folder-hash.sh"
# shellcheck source=./functions/healthcheck.sh
source "$COMMON_LIB_ROOT/functions/healthcheck.sh"
# shellcheck source=./functions/container-systemd.sh
source "$COMMON_LIB_ROOT/functions/container-systemd.sh"

mapfile -t FILES < <(find "$COMMON_LIB_ROOT/standard_build_steps" -type f -name '*.sh')
for FELE in "${FILES[@]}"; do
	# shellcheck source=/dev/null
	source "$FELE"
done
unset FELE FILES

function create_if_not() {
	local NAME=$1 BASE=$2

	if is_ci; then
		info_log "[CI] Create container '$NAME' from image '$BASE'."
		new_container "$NAME" "$BASE"
	elif [[ $BASE == "scratch" ]]; then
		if container_exists "$NAME"; then
			info_log "Using exists container '$NAME'."
			container_get_id "$NAME"
		else
			info_log "Container '$NAME' not exists, create from image $BASE."
			new_container "$NAME" "$BASE"
		fi
	else
		if ! image_exists "$BASE"; then
			info_note "missing base image $BASE, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "$BASE" >&2
		fi

		local EXPECT GOT
		GOT=$(container_get_base_image_id "$NAME")
		EXPECT=$(image_get_id "$BASE")
		if [[ $EXPECT == "$GOT" ]]; then
			info_log "Using exists container '$NAME'."
			container_get_id "$NAME"
		elif [[ "$GOT" ]]; then
			info_log "Not using exists container: $BASE is updated"
			info_log "    current image:          $EXPECT"
			info_log "    exists container based: $GOT"
			buildah rm "$NAME" >/dev/null
			new_container "$NAME" "$BASE"
		else
			info_log "Container '$NAME' not exists, create from image $BASE."
			new_container "$NAME" "$BASE"
		fi
	fi
}

function container_exists() {
	local ID X
	ID=$(container_get_id "$1")
	X=$?
	if [[ $X -eq 0 ]] && [[ $ID == "" ]]; then
		info_warn "inspect container $1 success, but nothing return"
		return 1
	fi
	return $X
}

function image_exists() {
	local ID X
	ID=$(image_get_id "$1")
	X=$?
	if [[ $X -eq 0 ]] && [[ $ID == "" ]]; then
		info_warn "inspect image $1 success, but nothing return"
		return 1
	fi
	return $X
}

function image_get_id() {
	buildah inspect --type image --format '{{.FromImageID}}' "$1" 2>/dev/null
}
function image_find_id() {
	buildah inspect --type image --format '{{.FromImageID}}' "$1" 2>/dev/null || true
}

function container_get_id() {
	buildah inspect --type container --format '{{.ContainerID}}' "$1" 2>/dev/null
}
function container_find_id() {
	buildah inspect --type container --format '{{.ContainerID}}' "$1" 2>/dev/null || true
}
function container_get_base_image_id() {
	buildah inspect --type container --format '{{.FromImageID}}' "$1" 2>/dev/null
}

function is_id_digist() {
	echo "$*" | grep -qiE '^[0-9A-Z]+$'
}

function new_container() {
	local NAME=$1
	local EXISTS
	EXISTS=$(container_get_id "$NAME" || true)
	if [[ -n $EXISTS ]]; then
		info_log "Remove exists container '$EXISTS'"
		buildah rm "$EXISTS" >/dev/null
	fi
	local FROM="${2-scratch}"
	if [[ $FROM != scratch ]] && ! is_id_digist "$FROM"; then
		if is_ci; then
			info_note "[CI] base image $FROM, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "$FROM" >&2
		elif ! image_exists "$FROM"; then
			info_note "missing base image $FROM, pulling from registry (proxy=${http_proxy:-'*notset'})..."
			buildah pull "$FROM" >&2
		fi
	fi
	buildah from --name "$NAME" "$FROM"
}
