#!/bin/bash

echo "[entrypoint.sh]: arguments: $# - $*"
echo "[entrypoint.sh]: environments: (save to /run/.userenvironments)"
env

env >>/run/.userenvironments

if [[ $* == '--systemd' ]]; then
	exec /lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=no systemd.journald.forward_to_console=yes
fi

exec "$@"
