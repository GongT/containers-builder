#!/usr/bin/env bash

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
		export_script_variable CI
		export_script_function is_ci
		SHELL_USE_PROXY
		cat "$SCRIPT"
	} >"$SCRIPT_FILE"

	local MOUNT_SOURCE=()
	if [[ $SOURCE_DIRECTORY != no ]]; then
		MOUNT_SOURCE+=("--volume=$SOURCE_DIRECTORY:/opt/projects/$PROJECT_ID")
	fi

	if ! grep -q "group .*" "$SCRIPT_FILE"; then
		control_ci group "Compile $PROJECT_ID"
	fi
	buildah run \
		"--volume=$SYSTEM_COMMON_CACHE:/cache/common" \
		"--volume=$SYSTEM_FAST_CACHE:/cache/fast" \
		"${MOUNT_SOURCE[@]}" "$WORKER" bash <"$SCRIPT_FILE"
	if ! grep -q "group .*" "$SCRIPT_FILE"; then
		control_ci groupEnd
	fi
}
function run_install() {
	local -r SOURCE_IMAGE="$1" TARGET_CONTAINER="$2" PROJECT_ID=$3

	local PREPARE_SCRIPT
	if [[ $# -gt 3 ]]; then
		PREPARE_SCRIPT=$(<"$4")
	elif [[ ! -t 0 ]]; then
		PREPARE_SCRIPT=$(cat)
	else
		PREPARE_SCRIPT="make install"
	fi

	control_ci group "Install Project :: $PROJECT_ID"
	WORKER=$(new_container "install.$PROJECT_ID" "$SOURCE_IMAGE")
	collect_temp_container "$WORKER"

	local TMPF=$(create_temp_file install.script)
	{
		echo '#!/usr/bin/env bash'
		echo 'set -Eeuo pipefail'
		SHELL_ERROR_HANDLER
		declare -p PROJECT_ID
		export_script_variable CI
		export_script_function is_ci
		echo "mkdir -p /mnt/install"
		cat "$COMMON_LIB_ROOT/staff/mcompile/installer.sh"
		echo "$PREPARE_SCRIPT"
	} >"$TMPF"

	local TMPF2=$(create_temp_file install.script)
	cat <<-EOF >"$TMPF2"
		set -Eeuo pipefail
		MNT=\$(buildah mount "$TARGET_CONTAINER")
		buildah run "--volume=\$MNT:/mnt/install" "$WORKER" bash < "$TMPF"
	EOF
	if is_root; then
		bash "$TMPF2"
	else
		buildah unshare bash "$TMPF2"
	fi

	control_ci groupEnd
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
