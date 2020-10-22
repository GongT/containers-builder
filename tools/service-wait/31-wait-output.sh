#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_output() {
	sdnotify --status="wait:output"

	__run

	self_journal | while read -r line; do
		sdnotify "EXTEND_TIMEOUT_USEC=$((5 * 1000000))"
		if echo "$line" | grep -qE "$WAIT_OUTPUT"; then
			debug "== ---- output found ---- =="
			startup_done
		fi
	done
}
