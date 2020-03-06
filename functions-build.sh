source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

function create_if_not() {
    if [[ \
		$(buildah inspect --type container --format '{{.FromImageID}}' "$1") \
		==  \
		$(buildah inspect --type image --format '{{.FromImageID}}' "$2") \
	]]; then
		echo "Using exists container '$1'." >&2
		buildah inspect --type container --format '{{.Container}}' "$1" 
	else
		echo "Create container '$1' from image '$2'." >&2
		new_container "$1" "$2"
	fi
}

function new_container() {
	local NAME=$1
	local EXISTS=$(buildah inspect --type container --format '{{.Container}}' "$NAME" || true)
	if [[ -n "$EXISTS" ]]; then
		buildah rm "$EXISTS" &>/dev/null
	fi
	buildah from --name "$NAME" "${2-scratch}"
}
