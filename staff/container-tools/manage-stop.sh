#!/usr/bin/bash

declare -xr LABELID_STOP_COMMAND="me.gongt.cmd.stop"

# shellcheck source=../../package/include.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/service-library.sh"

get_label() {
	TMPL=$(printf '{{index .Config.Labels "%s"}}' "$1")
	podman container inspect -f "$TMPL" "${CONTAINER_ID}"
}

OUTPUT="$(podman container inspect -f '{{.State.Status}}' "${CONTAINER_ID}" 2>&1)"
if [[ ${OUTPUT} == *"no such container"* ]] || [[ ${OUTPUT} != "running" ]]; then
	echo "no need to stop, container already removed or stopped."
	exit 0
fi
echo "found container running..."

CMD=$(get_label "$LABELID_STOP_COMMAND" | jq '.[]' | tr '\n' ' ')
if [[ -n ${CMD} ]]; then
	eval "CMDS=(${CMD})"

	if [[ ${#CMDS[@]} -gt 0 ]]; then
		x podman container exec "${CONTAINER_ID}" "${CMDS[@]}"
		exit $?
	fi
fi

TimeoutStopUSec=$(systemd_service_property "${UNIT_NAME}" "TimeoutStopUSec")
TimeoutStopSec=$(timespan_seconds "${TimeoutStopUSec}")
TO=$((TimeoutStopSec - 10))
if [[ ${TO} -lt 0 ]]; then
	TO='-1'
fi
x podman stop "--time=${TO}" "${CONTAINER_ID}"
