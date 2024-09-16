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

function add_build_config() {
	if ! variable_exists COMMIT_CONFIGS; then
		print_failure "wrong call timing add_build_config()"
	fi
	COMMIT_CONFIGS+=("$@")
}
function add_run_argument() {
	if ! variable_exists COMMIT_CONFIGS; then
		print_failure "wrong call timing add_run_argument()"
	fi
	# noop
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
		if [[ ${PASSARGS[*]} != *'--from'* ]]; then
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
		if ! is_root; then
			xbuildah unshare "${BUILDAH}" "${ACTION}" "${EXARGS[@]}" "${PASSARGS[@]}"
			return
		fi
		;;
	from)
		# TODO: all image ids
		control_ci "set-env" "BASE_IMAGE_NAME" "${PASSARGS[*]: -1}"
		xbuildah_capture "${ACTION}" "${EXARGS[@]}" "${PASSARGS[@]}"
		local NAME_OR_ID="$(<"${MANAGER_TMP_STDOUT}")"
		if is_digist "$NAME_OR_ID"; then
			echo "$NAME_OR_ID"
		else
			container_get_digist "$NAME_OR_ID"
		fi
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

			COMMIT_CONFIGS+=(
				"--author=${AUTHOR}"
				"--comment="
			)

			if is_ci; then
				local HASH
				HASH=$(hash_current_folder | md5sum | awk '{print $1}')
				COMMIT_CONFIGS+=("--label=${LABELID_RESULT_HASH}=${HASH}")
			else
				COMMIT_CONFIGS+=("--unsetlabel=${LABELID_RESULT_HASH}")
			fi

			COMMIT_CONFIGS+=("--annotation=${ANNOID_CACHE_PREV_STAGE}-" "--annotation=${ANNOID_CACHE_HASH}-")

			local BASE_FULL_NAME= BASE_DIGIST=
			if [[ -n ${LAST_KNOWN_BASE} ]]; then
				BASE_FULL_NAME=$(image_find_full_name "${LAST_KNOWN_BASE}")
			fi
			if [[ -n ${BASE_FULL_NAME} ]]; then
				BASE_DIGIST=$(image_get_digist "${BASE_FULL_NAME}")
			fi
			LAST_KNOWN_BASE=
			if [[ -n ${BASE_FULL_NAME} && -n ${BASE_DIGIST} ]]; then
				COMMIT_CONFIGS+=("--annotation=${ANNOID_OPEN_IMAGE_BASE_NAME}=${BASE_FULL_NAME}")
				COMMIT_CONFIGS+=("--annotation=${ANNOID_OPEN_IMAGE_BASE_DIGIST}=${BASE_DIGIST}")
			else
				COMMIT_CONFIGS+=("--annotation=${ANNOID_OPEN_IMAGE_BASE_NAME}-")
				COMMIT_CONFIGS+=("--annotation=${ANNOID_OPEN_IMAGE_BASE_DIGIST}-")
			fi

			call_argument_config

			xbuildah config "${COMMIT_CONFIGS[@]}" "${CID}"
		else
			info_success "commiting cache image ${CID} as ${IID}"
		fi

		local OUTPUT
		## Note: current oci not support healthcheck, docker not correct save annotations
		OUTPUT=$(xbuildah commit "--format=oci" --rm --quiet "${PASSARGS[@]}")
		info_note "commit: ${OUTPUT}"
		control_ci set-env "LAST_COMMITED_IMAGE" "${OUTPUT}"
		if ! is_digist "${OUTPUT}"; then
			die "output wrong"
		fi
		echo "${OUTPUT}"
		return
		;;
	run)
		EXARGS+=("--mount=type=tmpfs,destination=/tmp")
		if [[ ${BUILDAH_EXTRA_ARGS+found} == found ]]; then
			EXARGS+=("${BUILDAH_EXTRA_ARGS[@]}")
		fi
		;;
	*) ;;
	esac

	xbuildah "${ACTION}" "${EXARGS[@]}" "${PASSARGS[@]}"
}
