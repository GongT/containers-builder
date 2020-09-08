#!/usr/bin/env bash

declare -xr SHARED_PROJECTS_ROOT="$MONO_ROOT_DIR/_shared_projects"

function get_shared_project_location() {
	echo "$SHARED_PROJECTS_ROOT/projects/$1"
}

function install_shared_project() {
	declare -xr PROJECT_NAME="$1"
	declare -xr INSTALL_TO="$2"

	declare -xr SYS_INSTALL=$(find_command install)
	(
		function install() {
			echo -e "\e[2m + install $*\e[0m" >&2
			local I
			for I; do
				if [[ "$I" = "$INSTALL_TO"* ]]; then
					"$SYS_INSTALL" "$@"
					return
				fi
			done
			die 'install must have an argument starts with $INSTALL_TO, or you will overwrite system file'
		}

		declare -xr PROJECT_ROOT="$(get_shared_project_location "$PROJECT_NAME")"
		declare -r BUILD_SCRIPT="$SHARED_PROJECTS_ROOT/build-script/$PROJECT_NAME.sh"
		info "build ${PROJECT_NAME}..."

		if ! [[ -f "$BUILD_SCRIPT" ]]; then
			die "Fatal: missing shared project builder file: $BUILD_SCRIPT"
		fi
		if ! [[ -d "$PROJECT_ROOT" ]]; then
			die "Fatal: missing shared project folder: $PROJECT_ROOT"
		fi

		if ! [[ -d "$INSTALL_TO" ]]; then
			mkdir "$INSTALL_TO"
		fi

		declare -xr MOUNT_INSTALL_TARGET="--volume=$INSTALL_TO:/install"
		declare -xr MOUNT_BUILD_SOURCE="--volume=$PROJECT_ROOT:/build"

		source "$BUILD_SCRIPT"
	)
}
