function run_compile() {
	local PROJECT_ID="$1" WORKER="$2" SCRIPT="$3"

	if [[ ${SOURCE_DIRECTORY+found} == found ]]; then
		if [[ $SOURCE_DIRECTORY == no ]]; then
			info_note "using source inside container."
		else
			info_note "using source from: $SOURCE_DIRECTORY"
			SOURCE_DIRECTORY="$(realpath "$SOURCE_DIRECTORY")"
		fi
	elif [[ ${COMPILE_SOURCE_DIRECTORY+found} == found ]]; then
		info_note "using source from: $COMPILE_SOURCE_DIRECTORY"
		SOURCE_DIRECTORY="$(realpath "$COMPILE_SOURCE_DIRECTORY")"
	else
		local SOURCE_DIRECTORY
		SOURCE_DIRECTORY="$(pwd)/source/$PROJECT_ID"
		info_note "using source from: $SOURCE_DIRECTORY"
	fi

	mkdir -p "$SYSTEM_FAST_CACHE/CCACHE"

	info "compile project in '$WORKER' by '$SCRIPT'"
	local SCRIPT_FILE
	SCRIPT_FILE=$(create_temp_file "mcompile.$PROJECT_ID")
	{
		SHELL_ERROR_HANDLER
		echo "export PROJECT_ID='$PROJECT_ID'"
		echo "export SYSTEM_COMMON_CACHE='/cache/common'"
		echo "export SYSTEM_FAST_CACHE='/cache/fast'"
		cat "$COMMON_LIB_ROOT/staff/mcompile/prefix.sh"
		SHELL_USE_PROXY
		cat "$SCRIPT"
	} >"$SCRIPT_FILE"

	local MOUNT_SOURCE=()
	if [[ $SOURCE_DIRECTORY != no ]]; then
		MOUNT_SOURCE+=("--volume=$SOURCE_DIRECTORY:/opt/projects/$PROJECT_ID")
	fi

	control_ci group "Compile Details"
	buildah run \
		"--volume=$SYSTEM_COMMON_CACHE:/cache/common" \
		"--volume=$SYSTEM_FAST_CACHE:/cache/fast" \
		"--volume=$SCRIPT_FILE:/opt/projects/compile.sh" \
		"${MOUNT_SOURCE[@]}" "$WORKER" bash /opt/projects/compile.sh
	control_ci groupEnd
}
function run_install() {
	local PROJECT_ID="$1" SOURCE_IMAGE="$2" COMPILE_TARGET_DIRECTORY=$3

	local WORKER
	WORKER=$(new_container "${PROJECT_ID}-result-copyout" "$SOURCE_IMAGE")

	local PREPARE_SCRIPT=""
	if [[ $# -eq 4 ]]; then
		PREPARE_SCRIPT=$(<"$4")
	elif [[ ! -t 0 ]]; then
		PREPARE_SCRIPT=$(cat)
	else
		die "No install script set"
	fi

	local SRC="$(mktemp)"
	{
		echo '#!/usr/bin/env bash'
		echo 'set -Eeuo pipefail'
		SHELL_ERROR_HANDLER
		echo "export PROJECT_ID='$PROJECT_ID'"
		cat "$COMMON_LIB_ROOT/staff/mcompile/installer.sh"
		echo "$PREPARE_SCRIPT"
	} >"$SRC"
	buildah run -t \
		"--volume=$SRC:/mnt/script.sh:ro" \
		"--volume=$COMPILE_TARGET_DIRECTORY:/mnt/install" \
		"$WORKER" bash "/mnt/script.sh"

	buildah rm "$WORKER"
}

function clean_submodule() {
	pushd "$1" &>/dev/null || die "no such submodule $1"

	if [[ -e .git ]]; then
		info_note "reset git repo ($(pwd))..."
		git clean -ffdx
		git reset --hard
	fi

	popd &>/dev/null || die "popd failed from $1"
}
