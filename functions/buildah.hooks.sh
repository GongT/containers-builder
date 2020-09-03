#!/usr/bin/env bash

function builah_get_annotation() {
	local IMAGE=$1 ANNO_NAME="$2"
	xbuildah inspect --type image -f "{{index .ImageAnnotations \"$ANNO_NAME\"}}" "$IMAGE"
}

function builah_get_label() {
	local IMAGE=$1 LABEL_NAME="$2"
	xbuildah inspect --type image -f "{{index .Docker.config.Labels \"$LABEL_NAME\"}}" "$IMAGE"
}

function xbuildah() {
	local ACT=$1
	shift
	{
		echo -ne "$_CURRENT_INDENT\e[0;2mbuildah \e[0;2;4m$ACT\e[0;2m "
		local I
		for I; do
			echo -n "[$I] "
		done
		echo -e "\e[0m"
	} >&2
	"$BUILDAH" "$ACT" "$@"
}

function buildah() {
	local ACTION=$1
	shift

	local PASSARGS=("$@")
	local EXARGS=()
	case "$ACTION" in
	from)
		control_ci "::set-env name=BASE_IMAGE_NAME::${PASSARGS[*]: -1}"
		;;
	commit)
		if [[ "${REWRITE_IMAGE_NAME+found}" = found ]]; then
			info "rewrite commit image name: $REWRITE_IMAGE_NAME"
			local LEN=$((${#PASSARGS[@]} - 1))
			PASSARGS=("${PASSARGS[@]:0:$LEN}" "$REWRITE_IMAGE_NAME")
		fi

		local IID="${PASSARGS[*]: -1}"
		local CID="${PASSARGS[*]: -2:1}"

		if is_ci; then
			control_ci "::set-env name=LAST_COMMITED_IMAGE::$IID"

			EXARGS+=("--rm")

			export LAST_COMMITED_IMAGE="$IID"
			local HASH
			HASH=$(hash_current_folder)
			xbuildah config --label "$LABELID_RESULT_HASH=$HASH" "$CID"
		else
			xbuildah config --label "$LABELID_RESULT_HASH-" "$CID"
		fi

		xbuildah config --annotation "$ANNOID_CACHE_PREV_STAGE-" --annotation "$ANNOID_CACHE_HASH-" "$CID"
		;;
	esac

	xbuildah "$ACTION" "${EXARGS[@]}" "${PASSARGS[@]}"
}
