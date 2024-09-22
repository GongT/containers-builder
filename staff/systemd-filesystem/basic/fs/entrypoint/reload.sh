#!/usr/bin/env bash

echo "[systemd] reloading..."

declare -i RET=0
for I in *; do
	if [[ -s $I ]]; then
		echo "[systemd] execute script: $I"
		bash "$I"
		if [[ $? -ne 0 ]]; then
			RET=$?
		fi
	else
		echo "[systemd] reload service: $I"
		systemctl reload --no-block "$I"
		if [[ $? -ne 0 ]]; then
			RET=$?
		fi
	fi
done < <(find /entrypoint/reload.d -maxdepth 1 -type f -print0 | sort | grep -vF README.md)
echo "[systemd] reload complete"

exit $RET
