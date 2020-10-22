#!/usr/bin/env bash
set -Eeuo pipefail

function ensure_mounts() {
	local I
	for I; do
		if ! [[ -e $I ]]; then
			/usr/bin/mkdir -p "$I" || critical_die "can not ensure exists: $I"
		fi
	done
}
