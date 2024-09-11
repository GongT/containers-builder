#!/usr/bin/env bash
set -Eeuo pipefail

declare -r ANNO_MY_HEALTHCHECK="healthcheck"
function is_image_has_healthcheck() {
	[[ ${ARGS[*]} == *"--healthcheck="* ]]
}

DEF=$(get_image_annotation "${ANNO_MY_HEALTHCHECK}" 2>/dev/null)
json_array_get_back HC_ARGS "${DEF}"
if [[ ${#HC_ARGS[@]} -gt 0 ]]; then
	echo "load healthcheck arguments." >&2
	add_run_argument "${HC_ARGS[@]}"
else
	echo "image using healthcheck." >&2
fi
unset DEF HC_ARGS
