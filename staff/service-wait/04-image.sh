#!/usr/bin/env bash
set -Eeuo pipefail

declare -r ANNO_USING_SYSTEMD="me.gongt.using.systemd"

function inspect_image() {
	podman image inspect "${PODMAN_IMAGE_NAME}" | jq '.[0]'
}
function get_image_annotation() {
	podman image inspect "${PODMAN_IMAGE_NAME}" | jq '.[0].Labels[$tag]' --arg tag "$1"
}
function get_image_label() {
	podman image inspect "${PODMAN_IMAGE_NAME}" | jq '.[0].Annotations[$tag]' --arg tag "$1"
}

function is_image_using_systemd() {
	[[ $(get_image_annotation "${ANNO_USING_SYSTEMD}" 2>/dev/null) == yes ]]
}
