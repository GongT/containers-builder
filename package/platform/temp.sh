#!/usr/bin/env bash

if [[ -n ${RUNNER_TEMP-} ]]; then
	TMPDIR="${RUNNER_TEMP}"
else
	if [[ -n ${XDG_RUNTIME_DIR-} ]]; then
		TMPDIR="${XDG_RUNTIME_DIR}/tmp"
	elif [[ -z ${TMPDIR-} ]] || [[ ${TMPDIR} == '/tmp' ]]; then
		TMPDIR="${SYSTEM_FAST_CACHE}/tmp"
	fi
	if [[ ${NO_DELETE_TEMP-} != yes ]]; then
		TMPDIR=$(realpath -m "$TMPDIR/container-builder/${PROJECT_NAME}.$(date +%Y%m%d%H%M%S)")
	else
		TMPDIR=$(realpath -m "$TMPDIR/container-builder/${PROJECT_NAME}")
		rm -rf "${TMPDIR}"
	fi
fi

mkdir -p "${TMPDIR}"
declare -xr TMPDIR

declare -xr TMP_REGISTRY_FILE="${TMPDIR}/other-tempfiles"
declare -xr TMP_CONTAINER_FILE="${TMPDIR}/temp-containers"
declare -xr TMP_IMAGE_FILE="${TMPDIR}/temp-images"
touch "${TMP_REGISTRY_FILE}" "${TMP_CONTAINER_FILE}" "${TMP_IMAGE_FILE}"

if [[ ${NO_DELETE_TEMP-no} != yes ]]; then
	if ! is_ci; then
		register_exit_handler __exit_delete_container
		register_exit_handler __exit_delete_temp_files
	fi
else
	register_exit_handler echo "no delete temp: NO_DELETE_TEMP is set; location is ${TMPDIR}"
fi

function create_temp_dir() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	DIR=$(mktemp "--tmpdir=${TMPDIR}" --directory "${FILE_BASE}.XXXXX.${FILE_EXT}")
	[[ -d ${DIR} ]] || die "failed create temp dir"
	echo "${DIR}"
}

function create_temp_file() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	FILE=$(mktemp "--tmpdir=${TMPDIR}" "${FILE_BASE}.XXXXX.${FILE_EXT}")
	[[ -f ${FILE} ]] || die "failed create temp file"
	echo "${FILE}"
}

function collect_temp_file() {
	local F
	for F; do
		echo "${F}" >>"${TMP_REGISTRY_FILE}"
	done
}

function __exit_delete_temp_files() {
	local TEMP_TO_DELETE I
	mapfile -t TEMP_TO_DELETE <"${TMP_REGISTRY_FILE}"

	info_note "destroy temporary content at ${TMPDIR}\n\t(set NO_DELETE_TEMP=yes to prevent)"
	rm -rf "${TMPDIR}"

	if [[ ${#TEMP_TO_DELETE[@]} -eq 0 ]]; then
		info_note "no extra temporary files"
		return
	fi

	info_note "deleting extra temporary files..."
	indent
	for I in "${TEMP_TO_DELETE[@]}"; do
		if [[ -e ${I} ]]; then
			info_note "delete ${I}"
			rm -vrf "${I}"
		fi
	done
	dedent
}

function collect_temp_container() {
	local F
	for F; do
		echo "${F}" >>"${TMP_CONTAINER_FILE}"
	done
}
function collect_temp_image() {
	local F
	for F; do
		echo "${F}" >>"${TMP_IMAGE_FILE}"
	done
}
function __exit_delete_container() {
	local TODEL_IMG TODEL_CTR I
	mapfile -t TODEL_CTR <"${TMP_CONTAINER_FILE}"
	mapfile -t TODEL_IMG <"${TMP_IMAGE_FILE}"

	if [[ ${#TODEL_CTR[@]} -eq 0 && ${#TODEL_IMG[@]} -eq 0 ]]; then
		info_note "no temporary container or image"
		return
	fi

	info_note group "deleting ${#TODEL_IMG[@]} containers and ${#TODEL_CTR[@]} images..."
	info_note "\t(set NO_DELETE_TEMP=yes to prevent)"
	indent
	if [[ ${#TODEL_CTR[@]} -ne 0 ]]; then
		xbuildah rm "${TODEL_CTR[@]}" >/dev/null
	fi
	if [[ ${#TODEL_IMG[@]} -ne 0 ]]; then
		xpodman image rm "${TODEL_IMG[@]}" >/dev/null
	fi
	dedent
}
