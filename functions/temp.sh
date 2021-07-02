#!/usr/bin/env bash

declare -a TEMP_TO_DELETE=()
declare -a CONTAINER_TO_DELETE=()

if [[ ! ${TMPDIR:-} ]] || [[ $TMPDIR == '/tmp' ]]; then
	TMPDIR="$SYSTEM_FAST_CACHE/tmp"
	mkdir -p "$TMPDIR"
fi
export TMPDIR

function create_temp_dir() {
	local NAME=".unknown-usage"
	if [[ $# -ne 0 ]]; then
		NAME=".$1"
	fi
	local DIR
	DIR=$(mktemp "--tmpdir=$TMPDIR" --directory "containers.builder${NAME}.XXXX")
	[[ -d $DIR ]] || die "failed create temp dir"
	TEMP_TO_DELETE+=("$DIR")
	echo "$DIR"
}

function create_temp_file() {
	local NAME=".unknown-usage"
	if [[ $# -ne 0 ]]; then
		NAME=".$1"
	fi
	local FILE
	FILE=$(mktemp "--tmpdir=$TMPDIR" "containers.builder${NAME}.XXXX")
	[[ -f $FILE ]] || die "failed create temp file"
	TEMP_TO_DELETE+=("$FILE")
	echo "$FILE"
}

function collect_temp_file() {
	TEMP_TO_DELETE+=("$@")
}

function __exit_delete_temp_files() {
	if [[ ${#TEMP_TO_DELETE[@]} -eq 0 ]]; then
		return
	fi
	info_note "deleting temp files..."
	rm -rf "${TEMP_TO_DELETE[@]}"
}

function collect_temp_container() {
	if [[ ${#TEMP_TO_DELETE[@]} -eq 0 ]]; then
		return
	fi
	info_note "deleting temp containers..."
	if [[ ${BUILDAH+found} == found ]]; then
		"$BUILDAH" rm "${CONTAINER_TO_DELETE[@]}" &>/dev/null || true
	else
		podman rm "${CONTAINER_TO_DELETE[@]}" &>/dev/null || true
	fi
}
function __exit_delete_container() {
	if [[ ${#CONTAINER_TO_DELETE[@]} -eq 0 ]]; then
		return
	fi
	info_note "deleting temp containers..."
	if [[ ${BUILDAH+found} == found ]]; then
		"$BUILDAH" rm "${CONTAINER_TO_DELETE[@]}"
	else
		podman rm -f "${CONTAINER_TO_DELETE[@]}"
	fi
}

register_exit_handler __exit_delete_container

if [[ "${RUNNER_TEMP:-}" ]]; then
	export TMPDIR="$RUNNER_TEMP"
else
	register_exit_handler __exit_delete_temp_files
fi
