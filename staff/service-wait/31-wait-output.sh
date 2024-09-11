#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_output() {
	self_journal | while read -r line; do
		expand_timeout_seconds "5"
		if echo "${line}" | grep -qE "${WAIT_OUTPUT}"; then
			debug "== ---- output found ---- =="
			break
		fi
	done
}
