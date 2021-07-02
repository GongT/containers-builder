#!/usr/bin/env bash

CACHE_REGISTRY_ARGS=()
if [[ ${DOCKER_CACHE_CENTER_AUTH:-} ]]; then
	CACHE_REGISTRY_ARGS+=("--creds=$DOCKER_CACHE_CENTER_AUTH")
fi

function cache_try_pull() {
	if [[ ! ${DOCKER_CACHE_CENTER:-} ]]; then
		LAST_CACHE_COMES_FROM=build
		return
	fi

	local OUTPUT
	local URL="$1"
	control_ci group "pull cache image $URL"
	for ((I = 0; I < 3; I++)); do
		info_note "try pull cache image $URL"
		if OUTPUT=$(deny_proxy podman pull "${CACHE_REGISTRY_ARGS[@]}" "$URL" 2>&1); then
			info_note "  - success."
			LAST_CACHE_COMES_FROM=pull
			control_ci groupEnd
			return
		else
			if echo "$OUTPUT" | grep -q -- 'manifest unknown' \
				|| echo "$OUTPUT" | grep -q -- 'name unknown'; then
				info_note " - failed, not exists."
				LAST_CACHE_COMES_FROM=build
				control_ci groupEnd
				return
			else
				info_note " - failed."
			fi
		fi
	done

	control_ci groupEnd
	echo "$OUTPUT" >&2
	die "failed pull cache image!"
}
function cache_push() {
	if [[ ! ${DOCKER_CACHE_CENTER:-} ]] || [[ $LAST_CACHE_COMES_FROM == "pull" ]]; then
		return
	fi

	local URL="$1"
	control_ci group "push cache image $URL ($LAST_CACHE_COMES_FROM)"
	deny_proxy podman push "${CACHE_REGISTRY_ARGS[@]}" "$URL"
	control_ci groupEnd
}
