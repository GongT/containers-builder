#!/usr/bin/env bash

function mount_tmpfs() {
	local PATH=$1 SIZE="4G"
	shift
	if [[ $# -gt 0 ]]; then
		SIZE=$1
	fi
	echo "--mount=type=tmpfs,tmpfs-size=${SIZE},destination=${PATH}"
}

function image_get_annotation() {
	local IMAGE=$1 ANNO_NAME="$2"
	xpodman image inspect -f "{{index .Annotations \"${ANNO_NAME}\"}}" "${IMAGE}"
}

function image_get_label() {
	local IMAGE=$1 LABEL_NAME="$2"
	xpodman image inspect -f "{{index .Labels \"${LABEL_NAME}\"}}" "${IMAGE}"
}

function _add_config() {
	if ! is_set COMMIT_CONFIGS; then
		die "wrong call timing"
	fi
	COMMIT_CONFIGS+=("$@")
}

function buildah() {
	local ACTION=$1
	shift

	local PASSARGS=("$@")
	local -i LEN=$((${#PASSARGS[@]} - 1))
	local EXARGS=()
	case "${ACTION}" in
	"copy")
		EXARGS+=(--quiet)
		if ! [[ ${PASSARGS[*]} == *'--from'* ]]; then
			# convert source file to absolute (for debug)
			local -i I="${LEN} - 1"
			while [[ ${I} -gt 0 ]]; do
				local CCI=${I}
				I="${I} - 1"
				if [[ ${PASSARGS[${I}]} == -* ]]; then
					break
				fi

				local SRCF="${PASSARGS[${CCI}]}"
				if [[ ${SRCF} != /* ]]; then
					PASSARGS[${CCI}]="$(pwd)/${SRCF}"
				fi
			done
		fi
		;;
	mount | unmount)
		xbuildah unshare buildah "${ACTION}" "${PASSARGS[@]}"
		return
		;;
	from)
		# TODO: all image ids
		control_ci "set-env" "BASE_IMAGE_NAME" "${PASSARGS[*]: -1}"
		local OUTPUT_ID
		OUTPUT_ID=$(xbuildah "${ACTION}" "${EXARGS[@]}" "${PASSARGS[@]}")
		digist_to_short "${OUTPUT_ID}"
		return
		;;
	commit)
		local IID="${PASSARGS[*]: -1}"   # Image Id
		local CID="${PASSARGS[*]: -2:1}" # Container Id

		if [[ ${IID} != "${CACHE_CENTER_NAME_BASE}"* ]]; then
			info_success "commiting final image ${CID} as ${IID}"
			local -a COMMIT_CONFIGS=()

			if [[ ${REWRITE_IMAGE_NAME+found} == found ]]; then
				info "rewrite commit image name: ${REWRITE_IMAGE_NAME}"
				PASSARGS=("${PASSARGS[@]:0:LEN}" "${REWRITE_IMAGE_NAME}")
			fi

			if is_ci; then
				local HASH
				HASH=$(hash_current_folder | md5sum | awk '{print $1}')
				COMMIT_CONFIGS+=("--label=${LABELID_RESULT_HASH}=${HASH}")
			else
				COMMIT_CONFIGS+=("--unsetlabel=${LABELID_RESULT_HASH}")
			fi

			if [[ -n ${GITHUB_SERVER_URL-} ]] && [[ -n ${GITHUB_REPOSITORY-} ]]; then
				COMMIT_CONFIGS+=("--annotation=org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}")
			fi
			if [[ -n ${GITHUB_SHA-} ]]; then
				COMMIT_CONFIGS+=("--annotation=org.opencontainers.image.version=${GITHUB_SHA}")
			fi

			COMMIT_CONFIGS+=("--annotation=${ANNOID_CACHE_PREV_STAGE}-" "--annotation=${ANNOID_CACHE_HASH}-")

			## healthcheck.sh
			_healthcheck_config_buildah

			## stop.sh
			_stopreload_config_buildah

			xbuildah config "${COMMIT_CONFIGS[@]}" "${CID}"
		else
			info_success "commiting cache image ${CID} as ${IID}"
		fi

		local OUTPUT
		OUTPUT=$(xbuildah commit --rm --quiet "${PASSARGS[@]}")
		info_note "commit: ${OUTPUT}"
		control_ci "set-env" "LAST_COMMITED_IMAGE" "${OUTPUT}"

		digist_to_short "${OUTPUT}"
		return
		;;
	run)
		if [[ ${BUILDAH_EXTRA_ARGS+found} == found ]]; then
			EXARGS+=("${BUILDAH_EXTRA_ARGS[@]}")
		fi
		;;
	*) ;;
	esac

	xbuildah "${ACTION}" "${EXARGS[@]}" "${PASSARGS[@]}"
}
