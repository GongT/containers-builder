declare -xr BUILDAH_FORMAT=oci

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
declare -r MANAGER_TMP_STDERR="/tmp/container.manager.stderr.txt" MANAGER_TMP_STDOUT="/tmp/container.manager.stdout.txt"

function execute_tip() {
	local -ri ACT_CNT=$1
	shift
	local -r CMD=$1
	shift

	local ARGS=("$@")
	local -r ACT="${ARGS[*]:0:ACT_CNT}"
	local -r EXTRA="${ARGS[*]:ACT_CNT}"
	printf '%s \e[4m%s\e[24m %s' "${CMD}" "${ACT}" "${EXTRA}"
}

function xpodman() {
	local TIP
	TIP=" + $(execute_tip 2 podman "$@")"

	if [[ $1 == image ]] && is_tty && [[ $2 == pull || $2 == push ]]; then
		save_cursor_position
		info_warn "${TIP}"
	else
		info_note "${TIP}"
	fi
	"${PODMAN}" "$@"

	if [[ $1 == image ]] && is_tty && [[ $2 == pull || $2 == push ]]; then
		restore_cursor_position
		info_note "${TIP}"
	fi
}
function xpodman_capture() {
	local TIP
	TIP=" + $(execute_tip 2 podman "$@") >>"
	info_note "${TIP}"
	"${PODMAN}" "$@" 1>"${MANAGER_TMP_STDOUT}" 2>"${MANAGER_TMP_STDERR}"
}
function error_with_manager_output() {
	cat "${MANAGER_TMP_STDERR}" >&2
	exit 1
}
function xbuildah_capture() {
	info_note " + $(execute_tip 1 buildah "$@") >>"
	"${BUILDAH}" "$@" 1>"${MANAGER_TMP_STDOUT}" 2>"${MANAGER_TMP_STDERR}"
}
function xbuildah() {
	local ACT=$1

	local SGROUP=
	if (! is_ci) || [[ -n ${INSIDE_GROUP} ]] || [[ ${ACT} == run ]] || [[ ${ACT} == inspect ]] || [[ ${ACT} == config ]] || [[ ${ACT} == from ]]; then
		info_note " + $(execute_tip 1 buildah "$@")"
		indent
	else
		SGROUP=yes
		local OUT=$(execute_tip 1 buildah "$@")
		control_ci group "${OUT}"
	fi

	local -i X=-1
	if "${BUILDAH}" "$@"; then
		X=0
	else
		X=$?
		info_warn "buildah execute failed with ${X}"
	fi

	if [[ -n ${SGROUP} ]]; then
		control_ci groupEnd
	else
		dedent
	fi
	return "${X}"
}

function is_long_digist() {
	[[ $1 =~ ^[0-9a-fA-F]{64}$ ]]
}
function is_digist() {
	[[ $1 =~ ^[0-9a-fA-F]{64}$ ]] || [[ $1 =~ ^[0-9a-fA-F]{12}$ ]]
}
function digist_to_short() {
	if [[ $1 =~ ^[0-9a-fA-F]{64}$ || $1 =~ ^[0-9a-fA-F]{12}$ ]]; then
		echo "${1:0:12}"
	elif [[ -z $1 ]]; then
		echo
	else
		die "invalid digist: $1"
	fi
}

if is_ci; then
	function retry_execute() {
		shift
		shift

		x "$@"
	}
else
	function retry_execute() {
		local -ir MAX_TRY=$1 INTERVAL=$2
		shift
		shift

		if function_exists "$1"; then
			die "retry_execute do not support bash function"
		fi

		local -i TRY
		for ((TRY = 1; TRY < MAX_TRY; TRY++)); do
			if x "$@"; then
				return 0
			fi
			sleep "${INTERVAL}"
		done

		x "$@"
	}
fi
