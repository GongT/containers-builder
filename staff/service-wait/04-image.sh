_IMAGE_LABEL_JSON
function inspect_image() {
	if ! variable_exists _IMAGE_LABEL_JSON; then
		_IMAGE_LABEL_JSON=$(podman image inspect "${PODMAN_IMAGE_NAME}")
	fi
	jq -r '$ARGS.named.INPUT[0]' --argjson INPUT "${_IMAGE_LABEL_JSON}"
}
function get_image_annotation() {
	if ! variable_exists _IMAGE_LABEL_JSON; then
		_IMAGE_LABEL_JSON=$(podman image inspect "${PODMAN_IMAGE_NAME}")
	fi
	jq -r '$ARGS.named.INPUT[0].Annotations[$tag]' --arg tag "$1" --argjson INPUT "${_IMAGE_LABEL_JSON}"
}
function get_image_label() {
	if ! variable_exists _IMAGE_LABEL_JSON; then
		_IMAGE_LABEL_JSON=$(podman image inspect "${PODMAN_IMAGE_NAME}")
	fi
	jq -r '$ARGS.named.INPUT[0].Labels[$tag]' --arg tag "$1" --argjson INPUT "${_IMAGE_LABEL_JSON}"
}

declare SYSTEMD_DEFINATION=''
function is_image_using_systemd() {
	SYSTEMD_DEFINATION=$(get_image_label "${LABELID_USE_SYSTEMD}")
	[[ -n ${SYSTEMD_DEFINATION} && ${SYSTEMD_DEFINATION} != null ]]
}
