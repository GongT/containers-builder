#!/usr/bin/env bash

function run_compile() {
	local PROJECT_ID="$1" WORKER="$2" SCRIPT="$3"

	if [[ ${SOURCE_DIRECTORY+found} == found ]]; then
		if [[ ${SOURCE_DIRECTORY} == no ]]; then
			info_note "using source inside container."
		else
			info_note "using source from: ${SOURCE_DIRECTORY}"
			SOURCE_DIRECTORY="$(realpath "${SOURCE_DIRECTORY}")"
		fi
	elif [[ ${COMPILE_SOURCE_DIRECTORY+found} == found ]]; then
		info_note "using source from: ${COMPILE_SOURCE_DIRECTORY}"
		SOURCE_DIRECTORY="$(realpath "${COMPILE_SOURCE_DIRECTORY}")"
	else
		local SOURCE_DIRECTORY
		SOURCE_DIRECTORY="$(pwd)/source/${PROJECT_ID}"
		info_note "using source from: ${SOURCE_DIRECTORY}"
	fi

	mkdir -p "${SYSTEM_FAST_CACHE}/CCACHE"

	info "compile project in '${WORKER}' by '${SCRIPT}'"
	local TMPF
	TMPF=$(create_temp_file "mcompile.${PROJECT_ID}.sh")

	EXTRA=$(
		cat <<-EOF
			export PROJECT_ID='${PROJECT_ID}'
			export SYSTEM_COMMON_CACHE='/cache/common'
			export SYSTEM_FAST_CACHE='/cache/fast'
		EOF
		cat "${COMMON_LIB_ROOT}/staff/mcompile/prefix.sh"
	)
	construct_child_shell_script "${TMPF}" "${SCRIPT}" "${EXTRA}"

	local MOUNT_SOURCE=()
	if [[ ${SOURCE_DIRECTORY} != no ]]; then
		MOUNT_SOURCE+=("--volume=${SOURCE_DIRECTORY}:/opt/projects/${PROJECT_ID}")
	fi

	control_ci group "Compile ${PROJECT_ID}"

	if [[ ${NO_DELETE_TEMP} == yes ]]; then
		local WHO_AM_I="${TMPF}"
	else
		local WHO_AM_I="${SCRIPT}"
	fi
	buildah_run_shell_script \
		"--volume=${SYSTEM_COMMON_CACHE}:/cache/common" \
		"--volume=${SYSTEM_FAST_CACHE}:/cache/fast" \
		"${MOUNT_SOURCE[@]}" \
		"${WORKER}" "${TMPF}"
	control_ci groupEnd
}
function run_install() {
	local -r SOURCE_IMAGE="$1" TARGET_CONTAINER="$2" PROJECT_ID=$3

	local PREPARE_SCRIPT='' EXTRA

	control_ci group "Install Project :: ${PROJECT_ID}"
	WORKER=$(new_container "install.${PROJECT_ID}" "${SOURCE_IMAGE}")
	collect_temp_container "${WORKER}"

	local TMPF=$(create_temp_file install.script)

	EXTRA=$(
		declare -p PROJECT_ID
		echo 'mkdir -p /mnt/install'
		echo 'function install_main() {'
		if [[ $# -gt 3 ]]; then
			cat "$4"
		else
			echo "make install"
		fi
		echo '}'
	)

	construct_child_shell_script "${TMPF}" "${COMMON_LIB_ROOT}/staff/mcompile/installer.sh" "${EXTRA}"

	local TGT
	TGT="$(create_temp_dir)"
	echo "install ${TARGET_CONTAINER} with WORKER=${WORKER} [using temp folder ${TGT}]"
	buildah_run_shell_script "--volume=${TGT}:/mnt/install" "${WORKER}" "${TMPF}"
	buildah add "${TARGET_CONTAINER}" "${TGT}/filesystem.tar" /

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
