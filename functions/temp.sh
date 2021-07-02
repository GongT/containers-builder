#!/usr/bin/env bash

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
declare -xr TMP_REGISTRY_FILE
TMP_CONTAINER_FILE=$(mktemp "--tmpdir=$TMPDIR" "tempctrlist.XXXX")
declare -xr TMP_REGISTRY_FILE

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
	local F
	for F; do
		echo "$F" >>"$TMP_CONTAINER_FILE"
	done
}
function __exit_delete_container() {
	local TEMP_TO_DELETE I
	mapfile -t TEMP_TO_DELETE <"$TMP_CONTAINER_FILE"
	control_ci group "deleting temp containers..."
	for I in "${TEMP_TO_DELETE[@]}"; do
		if [[ ${BUILDAH+found} == found ]]; then
			"$BUILDAH" rm "$I" || true
		else
			buildah rm "$I" || true
		fi
	done
	control_ci groupEnd
}

register_exit_handler __exit_delete_container
