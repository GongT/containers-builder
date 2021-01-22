#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "./common_service_library.sh"

TARGET=${1:-www.google.com}

function try() {
	if [[ ! ${NOTIFY_SOCKET:-} ]]; then
		echo -ne "\e[2m"
	fi
	while true; do
		expand_timeout 32
		if nslookup -timeout=30 "$1" "$2" | grep -A 2 'answer:'; then
			echo "  - success"
			break
		fi
		echo "  - failed"
		sleep 1
	done
	if [[ ! ${NOTIFY_SOCKET:-} ]]; then
		echo -ne "\e[0m"
	fi
	startup_done
}

sdnotify " -> try resolve ${TARGET}"
try "$TARGET" 127.0.0.1
