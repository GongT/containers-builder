#!/usr/bin/env bash

echo "[systemd] reloading..."

declare -i RET=0
while read -r -d '' FILE; do
	if [[ $FILE == *.md ]]; then
		continue
	fi

	if [[ -s $FILE ]]; then
		echo "[systemd] execute script: $FILE"
		bash "$FILE"
		if [[ $? -ne 0 ]]; then
			RET=$?
		fi
	else
		echo "[systemd] reload service: $FILE"
		systemctl reload --no-block "$FILE"
		if [[ $? -ne 0 ]]; then
			RET=$?
		fi
	fi
done < <(find /entrypoint/reload.d -maxdepth 1 -type f -print0 | sort --zero-terminated)
echo "[systemd] reload complete"

exit $RET
