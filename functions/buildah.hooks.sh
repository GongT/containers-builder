#!/usr/bin/env bash

function mount_tmpfs() {
	local PATH=$1 SIZE="4G"
	shift
	if [[ $# -gt 0 ]]; then
		SIZE=$1
	fi
	echo "--mount=type=tmpfs,tmpfs-size=$SIZE,destination=$PATH"
}

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
		echo -ne "$_CURRENT_INDENT\e[0;2mbuildah \e[0;2;4m$ACT\e[0;2m"
		local I
		for I; do
			printf ' "%q"' "$I"
		done
		echo -e "\e[0m"
	} >&2
	"$BUILDAH" "$ACT" "$@"
}

function buildah() {
	local ACTION=$1
	shift

	local PASSARGS=("$@")
	local -i LEN=$((${#PASSARGS[@]} - 1))
	local EXARGS=()
	case "$ACTION" in
	copy)
		local DEST="${PASSARGS[*]: -1}"
		local -i I="$LEN - 1"
		while [[ $I -gt 0 ]]; do
			local CCI=$I
			I="$I - 1"
			if [[ ${PASSARGS[$I]} == -* ]]; then
				break
			fi

			local SRCF="${PASSARGS[$CCI]}"
			if [[ ${SRCF} != /* ]]; then
				PASSARGS[$CCI]="$(pwd)/$SRCF"
			fi
		done
		;;
	from)
		control_ci "set-env" "BASE_IMAGE_NAME" "${PASSARGS[*]: -1}"
		;;
	commit)
		if [[ ${REWRITE_IMAGE_NAME+found} == found ]]; then
			info "rewrite commit image name: $REWRITE_IMAGE_NAME"
			PASSARGS=("${PASSARGS[@]:0:LEN}" "$REWRITE_IMAGE_NAME")
		fi

		local IID="${PASSARGS[*]: -1}"
		local CID="${PASSARGS[*]: -2:1}"

		if [[ $CID != "$BUILDAH_CACHE_BASE/"* ]]; then
			if is_ci; then
				control_ci "set-env" "LAST_COMMITED_IMAGE" "$IID"

				EXARGS+=("--rm")

				export LAST_COMMITED_IMAGE="$IID"
				local HASH
				HASH=$(hash_current_folder)
				xbuildah config --label "$LABELID_RESULT_HASH=$HASH" "$CID"
			else
				xbuildah config --label "$LABELID_RESULT_HASH-" "$CID"
			fi
			xbuildah config --annotation "$ANNOID_CACHE_PREV_STAGE-" --annotation "$ANNOID_CACHE_HASH-" "$CID"
			_healthcheck_config_buildah "$CID"
		fi
		;;
	esac

	xbuildah "$ACTION" "${EXARGS[@]}" "${PASSARGS[@]}"
}
