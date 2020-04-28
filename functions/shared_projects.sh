declare -r _SHARED_PROJECTS_ROOT="$MONO_ROOT_DIR/_shared_projects"
_SHARED_PROJECTS_RESULT=""
CURRENT_SHARED_NAME=""

function commit_shared() {
	_SHARED_PROJECTS_RESULT="$1"
}

function copy_dist_program() {
	local MNT=$(buildah mount $1)
	cp "$_SHARED_PROJECTS_RESULT" "${MNT}/usr/bin/$CURRENT_SHARED_NAME"
	chmod 0777 "${MNT}/usr/bin/$CURRENT_SHARED_NAME"

	CURRENT_SHARED_NAME=
	_SHARED_PROJECTS_RESULT=
}

function load_shared_project() {
	CURRENT_SHARED_NAME=$1
	source "$_SHARED_PROJECTS_ROOT/build-script/$CURRENT_SHARED_NAME.sh"
}
