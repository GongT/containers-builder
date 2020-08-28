#!/usr/bin/env bash

function builah_get_annotation() {
	local IMAGE=$1 ANNO_NAME="$2"
	buildah inspect --type image -f "{{index .ImageAnnotations \"$ANNO_NAME\"}}" "$IMAGE"
}

function builah_get_label() {
	local IMAGE=$1 LABEL_NAME="$2"
	buildah inspect --type image -f "{{index .Docker.config.Labels \"$LABEL_NAME\"}}" "$IMAGE"
}

function buildah() {
	local ACTION=$1
	shift

	local EXARGS=()
	case "$ACTION" in
	commit)
		if [[ "${CI+found}" = found ]]; then
			EXARGS+=("--rm")

			local IID="${*: -1}"
			export LAST_COMMITED_IMAGE="$IID"
			local CID="${*: -2:1}"
			local HASH
			HASH=$(hash_current_folder)
			info_note "set image hash: $HASH"
			"$BUILDAH" config --label "$LABELID_RESULT_HASH=$HASH" "$CID"
		else
			"$BUILDAH" config --label "$LABELID_RESULT_HASH=" "$CID"
		fi
		;;
	esac

	{
		echo -ne "\e[0;2m"
		echo -n "$BUILDAH $ACTION ${EXARGS[*]} $*"
		echo -e "\e[0m"
	} >&2

	"$BUILDAH" "$ACTION" "${EXARGS[@]}" "$@"
}
