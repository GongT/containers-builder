#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "./common_service_library.sh"

mapfile -t UNIT_FILES < <(
	systemctl list-unit-files --type=mount --state=generated \
		--all --no-pager | grep --fixed-strings '.mount' | awk '{print $1}'
)

echo "unit files to wait:"
for i in "${UNIT_FILES[@]}"; do
	echo "  * $i"
done

for i in "${UNIT_FILES[@]}"; do
	I=0
	echo "wait $i"
	while ! systemctl is-active -q -- "$i"; do
		expand_timeout 5
		systemctl start --no-block "$i"
		I=$((I + 1))
		sdnotify "wait $i ($I)"
		if systemctl is-failed -q -- "$i"; then
			sdnotify "failed wait $i"
			exit 1
		fi
		sleep 1

		if [[ $I -gt 60 ]]; then
			sdnotify "timeout wait $i"
			exit 1
		fi
	done
	sdnotify "done $i ($I)"
done

startup_done
