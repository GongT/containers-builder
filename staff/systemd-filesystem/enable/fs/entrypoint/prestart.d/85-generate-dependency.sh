#!/usr/bin/bash

function generate() {
	local UNIT REQ_ARR WANT_ARR BG_ARR
	#shellcheck source=/dev/null
	source /entrypoint/systemd.d/enable.sh

	log "生成依赖关系: ${#REQ_ARR[@]} 必需 | ${#WANT_ARR[@]} 希望 | ${#BG_ARR[@]} 可选"
	for UNIT in "${REQ_ARR[@]}"; do
		systemd_unit_critical "$UNIT"
	done
	for UNIT in "${WANT_ARR[@]}"; do
		systemd_unit_wanted "$UNIT"
	done
	for UNIT in "${BG_ARR[@]}"; do
		systemd_unit_optional "$UNIT"
	done
}

generate
unset -f generate
