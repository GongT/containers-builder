function run_compile() {
	local PROJECT_ID="$1" WORKER="$2" SCRIPT="$3"

	if [[ "${SOURCE_DIRECTORY+found}" = found ]]; then
		SOURCE_DIRECTORY="$(realpath "$SOURCE_DIRECTORY")"
	else
		local SOURCE_DIRECTORY
		SOURCE_DIRECTORY="$(pwd)/source/$PROJECT_ID"
	fi

	mkdir -p "$SYSTEM_COMMON_CACHE/ccache"

	info "compile project in '$WORKER' by '$SCRIPT'"
	{
		cat <<- ARTIFACT
			export PROJECT_ID="$PROJECT_ID"
		ARTIFACT
		cat "$COMMON_LIB_ROOT/staff/mcompile/prefix.sh"
		SHELL_USE_PROXY
		cat "$SCRIPT"
	} | buildah \
		"--volume=$SYSTEM_COMMON_CACHE/ccache:/opt/cache" \
		"--volume=$SOURCE_DIRECTORY:/opt/projects/$PROJECT_ID" run "$BUILDER" bash
}
