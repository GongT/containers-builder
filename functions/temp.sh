#!/usr/bin/env bash

register_exit_handler __exit_delete_container

if [[ "${RUNNER_TEMP-}" ]]; then
	TMPDIR="$RUNNER_TEMP/"
else
	register_exit_handler __exit_delete_temp_files
	if [[ "${XDG_RUNTIME_DIR-}" ]]; then
		TMPDIR="$XDG_RUNTIME_DIR/tmp"
	elif [[ ! ${TMPDIR-} ]] || [[ $TMPDIR == '/tmp' ]]; then
		TMPDIR="$SYSTEM_FAST_CACHE/tmp"
	fi
fi
declare -xr TMPDIR=$(mktemp "--tmpdir=$TMPDIR" --directory --dry-run "container-builder-$PROJECT_NAME.XXX")
mkdir -p "$TMPDIR"

declare -xr TMP_REGISTRY_FILE="$TMPDIR/other-tempfiles"
declare -xr TMP_CONTAINER_FILE="$TMPDIR/temp-containers"
declare -xr TMP_IMAGE_FILE="$TMPDIR/temp-images"
touch "$TMP_REGISTRY_FILE" "$TMP_CONTAINER_FILE" "$TMP_IMAGE_FILE"

function create_temp_dir() {
	local NAME=".${1-unknown-usage}"
	local DIR
	DIR=$(mktemp "--tmpdir=$TMPDIR" --directory "containers.builder${NAME}.XXXX")
	[[ -d $DIR ]] || die "failed create temp dir"
	echo "$DIR"
}

function create_temp_file() {
	local NAME=".${1-unknown-usage}"
	local FILE
	FILE=$(mktemp "--tmpdir=$TMPDIR" "containers.builder${NAME}.XXXX")
	[[ -f $FILE ]] || die "failed create temp file"
	echo "$FILE"
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
			info_note "delete $I"
			rm -rf "$I"
		fi
	done

	rm -rf "$TMPDIR"

	control_ci groupEnd
}

function collect_temp_container() {
	local F
	for F; do
		echo "$F" >>"$TMP_CONTAINER_FILE"
	done
}
function collect_temp_image() {
	local F
	for F; do
		echo "$F" >>"$TMP_IMAGE_FILE"
	done
}
function __exit_delete_container() {
	local TODEL_IMG TODEL_CTR I
	mapfile -t TODEL_CTR <"$TMP_CONTAINER_FILE"
	mapfile -t TODEL_IMG <"$TMP_IMAGE_FILE"

	control_ci group "deleting temp containers and images..."
	if [[ ${#TODEL_CTR[@]} -ne 0 ]]; then
		x buildah rm "${TODEL_CTR[@]}" >/dev/null || true
	fi
	if [[ ${#TODEL_IMG[@]} -ne 0 ]]; then
		x podman rmi "${TODEL_IMG[@]}" >/dev/null || true
	fi
	control_ci groupEnd
}
