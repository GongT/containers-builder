source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

source "$COMMON_LIB_ROOT/functions/shared_projects.sh"
source "$COMMON_LIB_ROOT/functions/mdnf.sh"

function create_if_not() {
	local NAME=$1 BASE=$2
	if [[ "$BASE" = "scratch" ]]; then
		if container_exists "$NAME"; then
			echo "Using exists container '$NAME'." >&2
			buildah inspect --type container --format '{{.Container}}' "$NAME"
		else
			echo "Create container '$NAME' from image '$BASE'." >&2
			new_container "$NAME" "$BASE"
		fi
	elif [[ \
		$(buildah inspect --type container --format '{{.FromImageID}}' "$NAME" 2>&1) == \
		\
		$(buildah inspect --type image --format '{{.FromImageID}}' "$BASE" 2>&1) ]] \
			; then
		echo "Using exists container '$NAME'." >&2
		buildah inspect --type container --format '{{.Container}}' "$NAME"
	else
		echo "Create container '$NAME' from image '$BASE'." >&2
		new_container "$NAME" "$BASE"
	fi
}

function container_exists() {
	buildah inspect --type container --format '{{.FromImageID}}' "$1" &>/dev/null
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
	if [[ -n "$2" ]] && ! buildah inspect --type image --format '{{.FromImageID}}' "$2" &>/dev/null; then
		echo "Missing base image '$2'" >&2
	fi
	buildah from --name "$NAME" "${2-scratch}"
}

function SHELL_USE_PROXY() {
	echo "PROXY=$PROXY"
	echo '
if [ -n "$PROXY" ]; then
	echo "using proxy: ${PROXY}..." >&2
	export http_proxy="$PROXY"
	export https_proxy="$PROXY"
fi
'
}
