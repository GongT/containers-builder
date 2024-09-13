#!/bin/bash

echo "[entrypoint.sh]: arguments: $# - $*"
echo "[entrypoint.sh]: environments: (save to /run/.userenvironments)"

if [[ -t 1 ]]; then
	echo "stdout is tty"
else
	echo "stdout is not tty"
fi
if [[ -t 2 ]]; then
	echo "stderr is tty"
else
	echo "stderr is not tty"
fi

env >>/run/.userenvironments

echo "$container_uuid" >/etc/machine-id
echo "$container_uuid" >/run/machine-id

if [[ $* == '--systemd' ]]; then
	if [[ -e ${NOTIFY_SOCKET} ]]; then
		echo "__NOTIFY_SOCKET__=${NOTIFY_SOCKET}" >>/run/.userenvironments
		systemd-notify "--status=system boot up"
	fi
	unset NOTIFY_SOCKET

	capsh --print
	exec /usr/lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=yes --crash-reboot=no
fi

exec "$@"
