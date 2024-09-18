function current_image_find_annotation() {
	if ! variable_exists _IMAGE_LABEL_JSON; then
		_IMAGE_LABEL_JSON=$(podman image inspect "${PODMAN_IMAGE_NAME}")
	fi
	parse_json "${_IMAGE_LABEL_JSON}" '.[0].Annotations[$tag]' --arg tag "$1" || echo ''
}
function current_image_find_label() {
	if ! variable_exists _IMAGE_LABEL_JSON; then
		_IMAGE_LABEL_JSON=$(podman image inspect "${PODMAN_IMAGE_NAME}")
	fi
	parse_json "${_IMAGE_LABEL_JSON}" '.[0].Labels[$tag]' --arg tag "$1" || echo ''
}

declare SYSTEMD_DEFINATION=''
function current_image_is_using_systemd() {
	SYSTEMD_DEFINATION=$(current_image_find_label "${LABELID_USE_SYSTEMD}")
	[[ -n ${SYSTEMD_DEFINATION} ]]
}
