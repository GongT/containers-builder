#!/usr/bin/bash

source "../../package/include.sh"

use_normal

info_note "container name: ${CONTAINER_ID}"
STATE="$(container_get_status)"
if ! is_running_state "${STATE}"; then
	info_success "no need to stop, container already removed or stopped."
	wait_removal
	exit 0
fi
info_log "found container running..."

CMD=$(container_get_label "$LABELID_STOP_COMMAND" | jq '.[]' | tr '\n' ' ' || true)
if [[ -n ${CMD} ]]; then
	eval "CMDS=(${CMD})"

	if [[ ${#CMDS[@]} -gt 0 ]]; then
		info "call image defined stop command"
		x podman container exec "${CONTAINER_ID}" "${CMDS[@]}"
		wait_removal
		exit 0
	fi
fi
info "image did not define a stop command (use default)"

TimeoutStopUSec=$(systemd_service_property "${UNIT_NAME}" "TimeoutStopUSec")
TimeoutStopSec=$(timespan_seconds "${TimeoutStopUSec}")
TO=$((TimeoutStopSec - 10))
if [[ ${TO} -lt 0 ]]; then
	TO='-1'
fi
x podman container stop "--time=${TO}" "${CONTAINER_ID}"

info_success "container stopped."

wait_removal
