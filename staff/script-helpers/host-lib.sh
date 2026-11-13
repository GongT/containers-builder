#!/usr/bin/env bash

declare _CURRENT_INDENT=""

if variable_exists RUNTIME_DIRECTORY; then
	declare -xr RUNTIME_DIRECTORY
	declare -xr TMPDIR="${RUNTIME_DIRECTORY}/"
else
	declare -xr RUNTIME_DIRECTORY="/run"
	declare -xr TMPDIR="/tmp/image-build/"
fi

if [[ ${NOTIFY_SOCKET+found} == found ]]; then
	declare -xr __NOTIFYSOCKET=${NOTIFY_SOCKET}
	function sdnotify() {
		# echo "[SDNOTIFY] $*" >&2
		NOTIFY_SOCKET="${__NOTIFYSOCKET}" systemd-notify "$@"
	}
else
	function sdnotify() {
		echo "[SDNOTIFY] (disabled) $*" >&2
		:
	}
fi

function hide_sdnotify() {
	unset NOTIFY_SOCKET
}

function _SERVICE_exit_handler() {
	local _EXIT_CODE=$?
	set +xEeuo pipefail
	trap - ERR

	_CURRENT_INDENT='[exit] '

	# info_note "退出回调被调用: 上个命令返回=${_EXIT_CODE}, ERRNO=${ERRNO}, EXIT_CODE=${EXIT_CODE-missing}, 当前进程ID=$$"

	call_exit_handlers

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		info_error "命令执行返回码 ${_EXIT_CODE}"
	elif [[ ${EXIT_CODE-0} -ne 0 ]]; then
		info_error "服务主脚本退出码 ${EXIT_CODE}"
		_EXIT_CODE=${EXIT_CODE}
	elif [[ ${ERRNO} -ne 0 ]]; then
		info_error "非正常返回值 ${ERRNO}"
		_EXIT_CODE=${ERRNO}
	fi

	if [[ ${_EXIT_CODE} -ne 0 ]]; then
		if [[ -e ${ERRSTACK_FILE-not exists} ]]; then
			cat "${ERRSTACK_FILE}"
		else
			info_warn "栈信息不可用"
		fi
	fi

	exit $_EXIT_CODE
}
trap _SERVICE_exit_handler EXIT

function expand_timeout() {
	if [[ $1 -gt 0 ]]; then
		sdnotify "EXTEND_TIMEOUT_USEC=$1"
	fi
}
function expand_timeout_seconds() {
	if [[ $1 -gt 0 ]]; then
		sdnotify "EXTEND_TIMEOUT_USEC=$(($1 * 1000000 + 5000))"
	fi
}
function systemctl() {
	if [[ -z ${XDG_RUNTIME_DIR-} ]] || [[ $XDG_RUNTIME_DIR == */0 ]]; then
		/usr/bin/systemctl "$@"
	else
		/usr/bin/systemctl --user "$@"
	fi
}
function journalctl() {
	if [[ -z ${XDG_RUNTIME_DIR-} ]] || [[ $XDG_RUNTIME_DIR == */0 ]]; then
		/usr/bin/journalctl "$@"
	else
		/usr/bin/journalctl --user "$@"
	fi
}
function get_service_property() {
	systemctl show "${UNIT_NAME}" "--property=$1" --value
}

# if variable_exists

function is_ci() {
	false
}

function control_ci() {
	local -r ACTION="$1"
	shift
	# info_log "[CI] Action=$ACTION, Args=$*" >&2
	case "${ACTION}" in
	set-env)
		local NAME=$1 VALUE=$2
		export "${NAME}=${VALUE}"
		;;
	error | notice | warning)
		local TITLE=$1 MESSAGE=$2
		if [[ ${ACTION} == 'error' ]]; then
			info_error "[${TITLE}] ${MESSAGE}"
		elif [[ ${ACTION} == 'warning' ]]; then
			info_warn "[${TITLE}] ${MESSAGE}"
		elif [[ ${ACTION} == 'notice' ]]; then
			info "[${TITLE}] ${MESSAGE}"
		fi
		;;
	group)
		info_bright "[开始输出分组] $*"
		indent
		;;
	groupEnd)
		dedent
		info_note "[结束输出分组]"
		;;
	*)
		die "[非CI模式] 不支持的CI操作: ${ACTION}"
		;;
	esac
}

function try_resolve_file() {
	# TODO
	echo "$*"
}
function get_container_id() {
	if variable_exists CONTAINER_ID; then
		# must be in Exec*= in a service
		echo "${CONTAINER_ID}"
		return
	fi
	# shellcheck disable=SC2155
	local CONTAINER_ID=$(systemctl cat "${UNIT_FILE_NAME}" 2>&1 | grep -F Environment=CONTAINER_ID= | sed 's#^Environment=CONTAINER_ID=##g')
	if [[ ${CONTAINER_ID} == *%* ]]; then
		if [[ -z ${template_id-} ]]; then
			die "对于模板 (实例化 / 以 @ 结尾) 服务，必须有环境变量: template_id"
		fi
		filter_systemd_template "${CONTAINER_ID}"
	else
		echo "${CONTAINER_ID}"
	fi
}

function filter_systemd_template() {
	if [[ $1 == *%* && -z ${template_id-} ]]; then
		die "对于模板 (实例化 / 以 @ 结尾) 服务，必须有环境变量: template_id"
	fi
	echo "${1//%i/${template_id}}"
}

function create_temp_dir() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	if [[ ! -d ${TMPDIR} ]]; then
		mkdir -p "${TMPDIR}"
	fi
	mktemp "--tmpdir=${TMPDIR}" --directory "${FILE_BASE}.XXXXX.${FILE_EXT}"
}

function create_temp_file() {
	local FILE_NAME="${1-unknown-usage}"
	local DIR FILE_BASE="${FILE_NAME%.*}" FILE_EXT="${FILE_NAME##*.}"
	mktemp "--tmpdir" "--dry-run" "${FILE_BASE}.XXXXX.${FILE_EXT}"
}

function image_find_digits() {
	info_note ' +' podman image inspect --format '{{.ID}}' "$1"
	if OUTPUT=$(podman image inspect --format '{{.ID}}' "$1" 2>&1); then
		digits_to_short "${OUTPUT}"
	elif echo "${OUTPUT}" | grep -qF 'image not known'; then
		return 0
	else
		error_with_manager_output
	fi
}

function image_get_annotation() {
	local IMAGE=$1 ANNO_NAME="$2"
	x podman image inspect -f "{{index .Annotations \"${ANNO_NAME}\"}}" "${IMAGE}"
}

function image_get_label() {
	local IMAGE=$1 LABEL_NAME="$2"
	x podman image inspect -f "{{index .Labels \"${LABEL_NAME}\"}}" "${IMAGE}"
}

function container_get_annotation() {
	if [[ $# -eq 1 ]]; then
		local -r ID=$(get_container_id) ANNO_NAME="$1"
	elif [[ $# -eq 2 ]]; then
		local -r ID=$1 ANNO_NAME="$2"
	else
		die "错误调用 container_get_annotation"
	fi
	x podman container inspect -f "{{index .Config.Annotations \"${ANNO_NAME}\"}}" "${ID}"
}

function container_get_label() {
	if [[ $# -eq 1 ]]; then
		local -r ID=$(get_container_id) LABEL_NAME="$1"
	elif [[ $# -eq 2 ]]; then
		local -r ID=$1 LABEL_NAME="$2"
	else
		die "错误调用 container_get_label"
	fi
	x podman container inspect -f "{{index .Config.Labels \"${LABEL_NAME}\"}}" "${ID}"
}

# "configured",  "created",  "exited", "healthy", "initialized", "paused", "removing", "running", "stopped", "stopping", "unhealthy"
#    + "removed"
function container_get_status() {
	local OUTPUT ID=${1-"$(get_container_id)"}
	info_note ' +' podman container inspect -f '{{.State.Status}}' "${ID}"
	OUTPUT="$(podman container inspect -f '{{.State.Status}}' "${ID}" 2>&1 || true)"
	if [[ ${OUTPUT} == *"no such container"* ]]; then
		printf "removed"
	else
		printf '%s' "${OUTPUT}"
	fi
}

function is_running_state() {
	case "$1" in
	healthy | removing | running | stopping | paused)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

function wait_removal() {
	local ID=${1-"$(get_container_id)"} STATE
	sleep 1s

	info_note "等待容器 ${ID} 被移除:"
	while podman container exists "${ID}"; do
		sleep 1s
		STATE=$(container_get_status "${ID}")

		if is_running_state "${STATE}"; then
			info_note "  * 仍在运行 (我不会停止它)"
		elif [[ ${STATE} == 'removed' ]]; then
			info_note "  - 已消失"
			return
		else
			info_note "  * 已停止但未移除, 现在移除它 (我不会添加 --force 或 --depend)"
			x podman container rm "${ID}"
		fi
	done
}
