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
	OUT=$(
		echo -ne "$_CURRENT_INDENT\e[0;2mbuildah \e[0;2;4m$ACT\e[0;2m"
		local I
		for I; do
			printf ' %q' "$I"
		done
		echo -e "\e[0m"
	)

	local SGROUP=
	if (! is_ci) || [[ $INSIDE_GROUP ]] || [[ $ACT == run ]] || [[ $ACT == inspect ]] || [[ $ACT == config ]] || [[ $ACT == from ]]; then
		echo "$OUT" >&2
	else
		SGROUP=yes
		control_ci group "$OUT"
	fi

	"$BUILDAH" "$ACT" "$@"
	local X=$?

	if [[ "$SGROUP" ]]; then
		control_ci groupEnd
	fi
	return $X
}

function buildah() {
	local ACTION=$1
	shift

	local PASSARGS=("$@")
	local -i LEN=$((${#PASSARGS[@]} - 1))
	local EXARGS=()
	case "$ACTION" in
	copy)
		if ! [[ ${PASSARGS[*]} == *'--from'* ]]; then
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
		fi
		;;
	from)
		# TODO: all image ids
		control_ci "set-env" "BASE_IMAGE_NAME" "${PASSARGS[*]: -1}"
		;;
	commit)
		control_ci group "buildah commit"
		if [[ ${REWRITE_IMAGE_NAME+found} == found ]]; then
			info "rewrite commit image name: $REWRITE_IMAGE_NAME"
			PASSARGS=("${PASSARGS[@]:0:LEN}" "$REWRITE_IMAGE_NAME")
		fi

		local IID="${PASSARGS[*]: -1}"
		local CID="${PASSARGS[*]: -2:1}"

		if [[ $CID != "$BUILDAH_CACHE_BASE"* ]]; then
			control_ci "set-env" "LAST_COMMITED_IMAGE" "$IID"
			if is_ci; then
				EXARGS+=("--rm")

				local HASH
				HASH=$(hash_current_folder)
				xbuildah config --label "$LABELID_RESULT_HASH=$HASH" "$CID"
			else
				xbuildah config --label "$LABELID_RESULT_HASH-" "$CID"
			fi

			if [[ ${GITHUB_SERVER_URL:-} ]] && [[ ${GITHUB_REPOSITORY:-} ]]; then
				xbuildah config --annotation "org.opencontainers.image.source=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY" "$CID"
			fi
			if [[ ${GITHUB_SHA:-} ]]; then
				xbuildah config --annotation "org.opencontainers.image.version=$GITHUB_SHA" "$CID"
			fi

			xbuildah config --annotation "$ANNOID_CACHE_PREV_STAGE-" --annotation "$ANNOID_CACHE_HASH-" "$CID"
			_healthcheck_config_buildah "$CID"
		fi
		;;
	run)
		if [[ ${BUILDAH_EXTRA_ARGS+found} == found ]]; then
			EXARGS+=("${BUILDAH_EXTRA_ARGS[@]}")
		fi
		;;
	esac

	xbuildah "$ACTION" "${EXARGS[@]}" "${PASSARGS[@]}"
	local R=$?

	case "$ACTION" in
	commit)
		control_ci groupEnd
		;;
	esac

	return $R
}
