#!/usr/bin/env bash
set -Eeuo pipefail

function detect_image_using_systemd() {
	# add_run_argument "--log-driver=passthrough"
	add_run_argument "--attach=stdin,stdout,stderr"
	add_run_argument "--log-driver=none"
	add_run_argument "--tty"

	if [[ ${FORCE_SYSTEMD-} == "true" ]] || is_image_using_systemd; then
		debug "image is systemd: forced=${FORCE_SYSTEMD-false}, label=$(get_image_label "${LABELID_SYSTEMD}")"
		add_run_argument '--systemd=always' '--privileged=true'
	else
		add_run_argument '--systemd=false'
	fi
}
