#!/usr/bin/env bash
set -Eeuo pipefail

declare -r LABELID_SYSTEMD="me.gongt.using.systemd"

function inspect_image() {
	podman image inspect "${PODMAN_IMAGE_NAME}" | jq '.[0]'
}
function get_image_annotation() {
	podman image inspect "${PODMAN_IMAGE_NAME}" | jq '.[0].Labels[$tag]' --arg tag "$1"
}
function get_image_label() {
	podman image inspect "${PODMAN_IMAGE_NAME}" | jq '.[0].Annotations[$tag]' --arg tag "$1"
}

declare SYSTEMD_DEFINATION=''
function is_image_using_systemd() {
	SYSTEMD_DEFINATION=$(get_image_label "${LABELID_SYSTEMD}" 2>/dev/null)
	[[ -n ${SYSTEMD_DEFINATION} ]]
}
