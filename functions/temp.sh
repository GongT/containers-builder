#!/usr/bin/env bash

declare -a CONTAINER_TO_DELETE=()

if [[ ! ${TMPDIR:-} ]] || [[ $TMPDIR == '/tmp' ]]; then
	TMPDIR="$SYSTEM_FAST_CACHE/tmp"
	mkdir -p "$TMPDIR"
fi
if [[ "${RUNNER_TEMP:-}" ]]; then
	TMPDIR="$RUNNER_TEMP"
else
	register_exit_handler __exit_delete_temp_files
fi

export TMPDIR
TMP_REGISTRY_FILE=$(mktemp "--tmpdir=$TMPDIR" "tempfilelist.XXXX")
export TMP_REGISTRY_FILE

function create_temp_dir() {
	local NAME=".unknown-usage"
	if [[ $# -ne 0 ]]; then
		NAME=".$1"
	fi
	local DIR
	DIR=$(mktemp "--tmpdir=$TMPDIR" --directory "containers.builder${NAME}.XXXX")
	[[ -d $DIR ]] || die "failed create temp dir"
	echo "$DIR" | tee -a "$TMP_REGISTRY_FILE"
}

function create_temp_file() {
	local NAME=".unknown-usage"
	if [[ $# -ne 0 ]]; then
		NAME=".$1"
	fi
	local FILE
	FILE=$(mktemp "--tmpdir=$TMPDIR" "containers.builder${NAME}.XXXX")
	[[ -f $FILE ]] || die "failed create temp file"
	echo "$FILE" | tee -a "$TMP_REGISTRY_FILE"
}

function collect_temp_file() {
	local F
	for F; do
		echo "$F" >>"$TMP_REGISTRY_FILE"
	done
}

function __exit_delete_temp_files() {
	local TEMP_TO_DELETE I
	mapfile -t TEMP_TO_DELETE <"$TMP_REGISTRY_FILE"
	control_ci group "deleting temp files..."
	for I in "${TEMP_TO_DELETE[@]}"; do
		if [[ -e $I ]]; then
			echo "delete $I"
			rm -rf "$I"
		fi
	done
	control_ci groupEnd
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
