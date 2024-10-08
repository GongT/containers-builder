function container_exists() {
	local ID
	ID=$(container_find_digist "$1")
	[[ -n ${ID} ]]
}

function image_exists() {
	if xpodman_capture image inspect --format '{{.ID}}' "$1"; then
		return 0
	elif grep -qF 'image not known' "$MANAGER_TMP_STDERR"; then
		return 1
	else
		error_with_manager_output
	fi
}

function image_get_long_id() {
	xpodman image inspect --format '{{.ID}}' "$1"
}
function image_find_full_name() {
	local NAME_PART=$1 OUT LIST

	if [[ -z ${NAME_PART} ]]; then
		return
	fi

	if xpodman_capture image inspect "${NAME_PART}"; then
		OUT="$(<"${MANAGER_TMP_STDOUT}")"
	elif grep -qF "image not known" "${MANAGER_TMP_STDERR}"; then
		return
	else
		error_with_manager_output
	fi

	LIST=$(jq --raw-output --null-input '$ARGS.named.INPUT[0].NamesHistory + .[0].RepoTags | .[]' --argjson INPUT "${OUT}" | sort | uniq)
	if [[ -z ${LIST} ]]; then
		return
	fi
	if echo "${LIST}" | grep -vqF ':latest'; then
		echo "${LIST}" | grep -vF ':latest' | head -n1
	else
		echo "${LIST}" | head -n1
	fi
}
function image_get_digist() {
	if xpodman_capture image inspect --format '{{.ID}}' "$1"; then
		digist_to_short "$(<"${MANAGER_TMP_STDOUT}")"
	elif grep -qF 'image not known' "$MANAGER_TMP_STDERR"; then
		die "missing required image: $1"
	else
		error_with_manager_output
	fi
}
function image_find_digist() {
	if xpodman_capture image inspect --format '{{.ID}}' "$1"; then
		digist_to_short "$(<"${MANAGER_TMP_STDOUT}")"
	elif grep -qF 'image not known' "$MANAGER_TMP_STDERR"; then
		return 0
	else
		error_with_manager_output
	fi
}

function container_get_digist() {
	if xbuildah_capture inspect --type=container --format '{{.ContainerID}}' "$1"; then
		digist_to_short "$(<"${MANAGER_TMP_STDOUT}")"
	elif grep -qF 'container not known' "$MANAGER_TMP_STDERR"; then
		die "missing required build container: $1"
	else
		error_with_manager_output
	fi
}
function container_find_digist() {
	if xbuildah_capture inspect --type=container --format '{{.ContainerID}}' "$1"; then
		digist_to_short "$(<"${MANAGER_TMP_STDOUT}")"
	elif grep -qF 'container not known' "$MANAGER_TMP_STDERR"; then
		return 0
	else
		error_with_manager_output
	fi
}
function container_get_base_image_id() {
	if xbuildah_capture inspect --type=container --format '{{.FromImageID}}' "$1"; then
		digist_to_short "$(<"${MANAGER_TMP_STDOUT}")"
	elif grep -qF 'container not known' "$MANAGER_TMP_STDERR"; then
		die "missing required build container: $1"
	else
		error_with_manager_output
	fi
}
