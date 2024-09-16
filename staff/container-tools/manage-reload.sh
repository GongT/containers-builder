#!/usr/bin/bash

declare -xr LABELID_RELOAD_COMMAND="me.gongt.cmd.reload"

get_label() {
	TMPL=$(printf '{{index .Config.Labels "%s"}}' "$1")
	podman container inspect -f "$TMPL" "${CONTAINER_ID}"
}
die() {
	echo "$*" >&2
	exit 1
}
x() {
	echo " + $*" >&2
	"$@"
}

OUTPUT="$(podman container inspect -f '{{.State.Status}}' "${CONTAINER_ID}" 2>&1)"
if [[ ${OUTPUT} == *"no such container"* ]] || [[ ${OUTPUT} != "running" ]]; then
	echo "can not reload, container removed or stopped."
	exit 0
fi
echo "found container running..."

CMD=$(get_label "$LABELID_RELOAD_COMMAND" | jq '.[]' | tr '\n' ' ')
if [[ -n ${CMD} ]]; then
	eval "CMDS=(${CMD})"

	if [[ ${#CMDS[@]} -gt 0 ]]; then
		x podman container exec "${CONTAINER_ID}"  "${CMDS[@]}"
		exit $?
	fi
fi

if podman container inspect "${CONTAINER_ID}" | grep -q -- "--systemd=always"; then
	echo "send sigterm to container systemd (this may not take effect)"
	x podman container kill --signal=sigterm "${CONTAINER_ID}"
else
	echo "send sighup to container (this may not take effect)"
	x podman container kill --signal=sighup "${CONTAINER_ID}"
fi