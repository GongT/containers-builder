if [[ -e "/usr/bin/podman" ]]; then
	PODMAN="/usr/bin/podman"
else
	PODMAN=$(find_command podman || die "podman not installed")
fi
declare -rx PODMAN

if [[ -e "/usr/bin/buildah" ]]; then
	BUILDAH="/usr/bin/buildah"
else
	BUILDAH=$(find_command buildah || die "buildah not installed")
fi
declare -rx BUILDAH

# shellcheck disable=SC2155
declare -r TMP_STDERR="/tmp/container.manager.stderr.txt" TMP_STDOUT="/tmp/container.manager.stdout.txt"

function error_with_manager_output() {
	cat "${TMP_STDERR}" >&2
	return 1
}
function execute_tip_format() {
	local -ri ACT_CNT=$1
	shift
	local -r CMD=$1
	shift

	local ARGS=("$@")
	local -r ACT="${ARGS[*]:0:ACT_CNT}"
	local -r EXTRA="${ARGS[*]:ACT_CNT}"
	printf '%s \e[4m%s\e[24m %s' "${CMD}" "${ACT}" "${EXTRA}"
}

function execute_tip() {
	# shellcheck disable=SC2312
	info_note "$(execute_tip_format "$@")"
}

function xpodman() {
	execute_tip 2 podman "$@"
	"${PODMAN}" "$@"
}
function xpodman_capture() {
	execute_tip 2 podman "$@"
	"${PODMAN}" "$@" 1>"${TMP_STDOUT}" 2>"${TMP_STDERR}"
}

function xbuildah_capture() {
	execute_tip 1 buildah "$@"
	"${BUILDAH}" "$@" 1>"${TMP_STDOUT}" 2>"${TMP_STDERR}"
}
function xbuildah() {
	local ACT=$1

	local SGROUP=
	if (! is_ci) || [[ -n ${INSIDE_GROUP} ]] || [[ ${ACT} == run ]] || [[ ${ACT} == inspect ]] || [[ ${ACT} == config ]] || [[ ${ACT} == from ]]; then
		execute_tip 1 buildah "$@"
		indent
	else
		SGROUP=yes
		# shellcheck disable=SC2155
		local OUT=$(execute_tip_format 1 buildah "$@")
		control_ci group "${OUT}"
	fi

	local -i X=-1
	if "${BUILDAH}" "$@"; then
		X=0
	else
		X=$?
		info_warn "failed with ${X}"
	fi

	if [[ -n ${SGROUP} ]]; then
		control_ci groupEnd
	else
		dedent
	fi
	return "${X}"
}
