#!/usr/bin/env bash
set -Eeuo pipefail

function detect_image_using_systemd() {
	if [[ ${FORCE_SYSTEMD-} == "true" ]] || is_image_using_systemd; then
		add_argument '--systemd=always' '--tty' '--tmpfs=/run'
	else
		add_argument '--systemd=false'
	fi
}
