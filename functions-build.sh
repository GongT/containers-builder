source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

function create_if_not() {
    if [[ \
		$( buildah inspect --type container --format '{{.FromImageID}}' "$1" 2>&1 ) \
		==  \
		$( buildah inspect --type image --format '{{.FromImageID}}' "$2" 2>&1 ) \
	]]; then
		echo "Using exists container '$1'." >&2
		buildah inspect --type container --format '{{.Container}}' "$1" 
	else
		echo "Create container '$1' from image '$2'." >&2
		new_container "$1" "$2"
	fi
}

function image_exists() {
	buildah inspect --type image --format '{{.FromImageID}}' "$1" &>/dev/null
}

function new_container() {
	local NAME=$1
	local EXISTS=$(buildah inspect --type container --format '{{.Container}}' "$NAME" 2>/dev/null || true)
	if [[ -n "$EXISTS" ]]; then
		echo "Remove exists container '$EXISTS'" >&2
		buildah rm "$EXISTS" &>/dev/null
	fi
	if [[ -n "$2" ]] && ! buildah inspect --type image --format '{{.FromImageID}}' "$2" &>/dev/null ; then
		echo "Missing base image '$2'" >&2
	fi
	buildah from --name "$NAME" "${2-scratch}"
}
