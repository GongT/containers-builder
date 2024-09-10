#!/usr/bin/env bash

register_exit_handler __exit_delete_container

if [[ -n ${RUNNER_TEMP-} ]]; then
	TMPDIR="${RUNNER_TEMP}/"
else
	register_exit_handler __exit_delete_temp_files
	if [[ -n ${XDG_RUNTIME_DIR-} ]]; then
		TMPDIR="${XDG_RUNTIME_DIR}/tmp"
	elif [[ -z ${TMPDIR-} ]] || [[ ${TMPDIR} == '/tmp' ]]; then
		TMPDIR="${SYSTEM_FAST_CACHE}/tmp"
	fi
fi

TMPDIR=$(mktemp "--tmpdir=${TMPDIR}" --directory --dry-run "container-builder-${PROJECT_NAME}.XXX")
mkdir -p "${TMPDIR}"
declare -xr TMPDIR

declare -xr TMP_REGISTRY_FILE="${TMPDIR}/other-tempfiles"
declare -xr TMP_CONTAINER_FILE="${TMPDIR}/temp-containers"
declare -xr TMP_IMAGE_FILE="${TMPDIR}/temp-images"
touch "${TMP_REGISTRY_FILE}" "${TMP_CONTAINER_FILE}" "${TMP_IMAGE_FILE}"

function create_temp_dir() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	DIR=$(mktemp "--tmpdir=${TMPDIR}" --directory "cb.${FILE_BASE}.XXXXX.${FILE_EXT}")
	[[ -d ${DIR} ]] || die "failed create temp dir"
	echo "${DIR}"
}

function create_temp_file() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	FILE=$(mktemp "--tmpdir=${TMPDIR}" "cb.${FILE_BASE}.XXXXX.${FILE_EXT}")
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

	rm -rf "${TMPDIR}"

	if [[ ${#TEMP_TO_DELETE[@]} -eq 0 ]]; then
		info_note "no extra temporary files"
		return
	fi

	control_ci group "deleting extra temporary files..."
	for I in "${TEMP_TO_DELETE[@]}"; do
		if [[ -e ${I} ]]; then
			info_note "delete ${I}"
			rm -vrf "${I}"
		fi
	done

	control_ci groupEnd
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

	control_ci group "deleting temporary containers and images..."
	if [[ ${#TODEL_CTR[@]} -ne 0 ]]; then
		x buildah rm "${TODEL_CTR[@]}" >/dev/null || true
	fi
	if [[ ${#TODEL_IMG[@]} -ne 0 ]]; then
		x podman rmi "${TODEL_IMG[@]}" >/dev/null || true
	fi
	control_ci groupEnd
}
