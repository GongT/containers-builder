#!/usr/bin/bash

source "../../package/include.sh"

use_normal

STATE="$(container_get_status)"
if ! is_running_state "${STATE}"; then
	info_warn "can not reload, container removed or stopped."
	exit 1
fi

CMD=$(image_get_label "$LABELID_RELOAD_COMMAND" | jq '.[]' | tr '\n' ' ')
if [[ -n ${CMD} ]]; then
	eval "CMDS=(${CMD})"

	if [[ ${#CMDS[@]} -gt 0 ]]; then
		info "call image defined reload command"
		x podman container exec "${CONTAINER_ID}" "${CMDS[@]}"
		exit $?
	fi
fi
info "image did not define a reload command (use default, may not have any effect)"

# if podman container inspect "${CONTAINER_ID}" | grep -q -- "--systemd=always"; then
# 	info_warn "send sigterm to container systemd (this may not take effect)"
# 	x podman container kill --signal=sigterm "${CONTAINER_ID}"
# else
info_warn "send sighup to container"
x podman container kill --signal=sighup "${CONTAINER_ID}"
# fi
