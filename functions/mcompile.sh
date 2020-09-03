function run_compile() {
	local PROJECT_ID="$1" WORKER="$2" SCRIPT="$3"

	local PROJECT_SRC="/opt/projects/$PROJECT_ID"

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
		"--volume=$(pwd)/source/$P:$PROJECT_SRC" run "$BUILDER" bash
}
