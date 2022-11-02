#!/bin/bash

echo "$# - $*"

if [[ $* == '--systemd' ]]; then
	exec /lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=no systemd.journald.forward_to_console=yes
fi

env >>/etc/environment

exec "$@"
