#!/usr/bin/env bash
set -Eeuo pipefail

function detect_image_using_systemd() {
	if [[ ${FORCE_SYSTEMD-} == "true" ]] || is_image_using_systemd; then
		debug "image is systemd: forced=${FORCE_SYSTEMD-false}, label=$(get_image_label "${LABELID_SYSTEMD}")"
		add_run_argument '--systemd=always' '--tty'
	else
		add_run_argument '--systemd=false'
	fi
}
