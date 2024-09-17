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
		# echo "[SDNOTIFY] (disabled) $*" >&2
		:
	}
fi

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

function hide_sdnotify() {
	unset NOTIFY_SOCKET
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
		info_bright "[Start Group] $*"
		indent
		;;
	groupEnd)
		dedent
		info_note "[End Group]"
		;;
	*)
		die "[None-CI] not support action: ${ACTION}"
		;;
	esac
}

function try_resolve_file() {
	# TODO
	echo "$*"
}
function get_container_id() {
	if [[ ${CONTAINER_ID} == *%* ]]; then
		if [[ -z ${template_id-} ]]; then
			die "for template (instantiated / ending with @) service, must have environment variable: template_id"
		fi
		filter_systemd_template "${CONTAINER_ID}"
	else
		echo "${CONTAINER_ID}"
	fi
}

function filter_systemd_template() {
	if [[ $1 == *%* && -z ${template_id-} ]]; then
		die "for template (instantiated / ending with @) service, must have environment variable: template_id"
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

function image_find_digist() {
	if OUTPUT=$(podman image inspect --format '{{.ID}}' "$1" 2>&1); then
		digist_to_short "${OUTPUT}"
	elif echo "${OUTPUT}" | grep -qF 'image not known'; then
		return 0
	else
		error_with_manager_output
	fi
}
