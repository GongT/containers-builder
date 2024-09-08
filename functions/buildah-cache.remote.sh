#!/usr/bin/env bash

CACHE_REGISTRY_ARGS=()
if [[ ${DOCKER_CACHE_CENTER_AUTH-} ]]; then
	CACHE_REGISTRY_ARGS+=("--creds=$DOCKER_CACHE_CENTER_AUTH")
fi

if [[ ! ${DOCKER_CACHE_CENTER-} ]]; then
	declare -rx DOCKER_CACHE_CENTER="dir:$SYSTEM_COMMON_CACHE/image-builder"
	mkdir --mode 0777 -p "$SYSTEM_COMMON_CACHE/image-builder"
fi

case "$DOCKER_CACHE_CENTER" in
oci-archive:* | dir:* | docker-archive:*)
	declare -rx CACHE_CENTER_TYPE="filesystem"
	CACHE_CENTER_URL_BASE="${DOCKER_CACHE_CENTER}"
	CACHE_CENTER_NAME_BASE="cache.example.com/simple"
	;;
*)
	declare -rx CACHE_CENTER_TYPE="network"
	CACHE_CENTER_URL_BASE="$DOCKER_CACHE_CENTER"
	CACHE_CENTER_NAME_BASE="${DOCKER_CACHE_CENTER#*:}"
	CACHE_CENTER_NAME_BASE="${CACHE_CENTER_NAME_BASE##/}"
	;;
esac
declare -xr CACHE_CENTER_URL_BASE CACHE_CENTER_NAME_BASE

function cache_create_name() {
	local CACHE_NAME=$1 CACHE_STAGE=$2
	echo "${CACHE_CENTER_NAME_BASE}:${CACHE_NAME}_stage_${CACHE_STAGE}"
}

function cache_create_url() {
	local CACHE_NAME=$1 CACHE_STAGE=$2
	if [[ $CACHE_CENTER_TYPE == 'network' ]]; then
		echo "${CACHE_CENTER_URL_BASE}:${CACHE_NAME}_stage_${CACHE_STAGE}"
	else
		echo "${CACHE_CENTER_URL_BASE}/${CACHE_NAME}/stage_${CACHE_STAGE}"
	fi
}

function cache_try_pull() {
	local -r URL=$(cache_create_url "$@")
	local -r NAME=$(cache_create_name "$@")

	local STDERR_FILE IMAGE
	STDERR_FILE=$(create_temp_file "cache-pull-output.txt")

	info_log "pull cache image $URL"
	local CMD=(podman pull --log-level=info --retry-delay 5s --retry 10 "${CACHE_REGISTRY_ARGS[@]}" "$URL")
	info_note " + ${CMD[*]}"

	local O
	if IMAGE=$("${CMD[@]}" 2>"$STDERR_FILE"); then
		if [[ $CACHE_CENTER_TYPE == 'filesystem' ]] && is_id_digist "$IMAGE"; then
			info_note "  - name local image to match cache name."
			podman tag "$IMAGE" "$NAME"
		fi
		LAST_CACHE_COMES_FROM=pull
		collect_temp_image "$NAME"

		info_note "  - success."
	else
		LAST_CACHE_COMES_FROM=local
		if grep -q -- 'manifest unknown' "$STDERR_FILE" \
			|| grep -q -- 'name unknown' "$STDERR_FILE" \
			|| grep -q -- 'no such file or directory' "$STDERR_FILE"; then
			info_note " - failed: not exists."
		else
			info_stream <"$STDERR_FILE"
			info_note " - failed, not able to pull."
			die "failed pull cache image!"
		fi
	fi
}
function cache_push() {
	local -r URL=$(cache_create_url "$@")
	local -r NAME=$(cache_create_name "$@")

	if [[ $CACHE_CENTER_TYPE == 'filesystem' ]]; then
		local FILEPATH="${URL#*:}"
		if [[ ${FILEPATH:0:1} != / ]]; then
			die "invalid local cache path: $URL"
		fi
		mkdir -p "$(dirname "$FILEPATH")"
	fi

	local -r CACHE_NAME=$1 CACHE_STAGE=$2
	if [[ $LAST_CACHE_COMES_FROM == "pull" ]]; then
		info_note "skip push cache of '$NAME', reason: last cache comes from pull."
		return
	fi

	control_ci group "push cache image '$NAME' (reason: $LAST_CACHE_COMES_FROM) to '$URL'"
	podman push "${CACHE_REGISTRY_ARGS[@]}" "$NAME" "$URL"
	collect_temp_image "$NAME"
	control_ci groupEnd
}
