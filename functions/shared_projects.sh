#!/usr/bin/env bash

declare -xr SHARED_PROJECTS_ROOT="$MONO_ROOT_DIR/_shared_projects"

function get_shared_project_location() {
	echo "$SHARED_PROJECTS_ROOT/projects/$1"
}

function install_shared_project() {
	declare -xr SYS_INSTALL=$(find_command install)
	(
		function install() {
			local ARGS=() FOUND_SP_ARG=
			while [[ "$#" -gt 0 ]]; do
				ARGS+=("$1")
				if [[ "$1" = "-d" ]] || [[ "$1" = "-t" ]]; then
					shift
					FOUND_SP_ARG=yes
					ARGS+=("$(realpath --canonicalize-missing --no-symlinks "$INSTALL_TO/$1")")
				fi
				shift
			done
			if [[ "$FOUND_SP_ARG" != "yes" ]]; then
				local -i L="${#ARGS} - 1"
				ARGS[$L]="$(realpath --canonicalize-missing --no-symlinks "$INSTALL_TO/${ARGS[$L]}")"
			fi

			"$SYS_INSTALL"
		}

		declare -xr PROJECT_NAME="$1"
		declare -xr PROJECT_ROOT="$(get_shared_project_location "$PROJECT_NAME")"
		declare -r BUILD_SCRIPT="$SHARED_PROJECTS_ROOT/build-script/$PROJECT_NAME.sh"
		info "build ${PROJECT_NAME}..."

		if ! [[ -f "$BUILD_SCRIPT" ]]; then
			die "Fatal: missing shared project builder file: $BUILD_SCRIPT"
		fi
		if ! [[ -d "$PROJECT_ROOT" ]]; then
			die "Fatal: missing shared project folder: $PROJECT_ROOT"
		fi

		declare -xr INSTALL_TO="$2"

		declare -xr MOUNT_INSTALL_TARGET="--volume=$INSTALL_TO:/install"
		declare -xr MOUNT_BUILD_SOURCE="--volume=$PROJECT_ROOT:/build"

		source "$BUILD_SCRIPT"
	)
}
