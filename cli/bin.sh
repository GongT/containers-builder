#!/bin/bash

use_normal

declare -ra ORIGINAL_ARGS=("$@")
if [[ $# -ge 1 ]]; then
	ACTION=${1-}
	shift
else
	ACTION=""
fi

if [[ ${UID} -eq 0 ]]; then
	declare -xr SCRIPTS_DIR="/usr/local/libexec/image-builder-cli"
else
	declare -xr SCRIPTS_DIR="${HOME}/.local/libexec/image-builder-cli"
	declare -r SYSTEMCTL=$(command -v systemctl)
	function systemctl() {
		"${SYSTEMCTL}" --user "$@"
	}
fi
cd "${SCRIPTS_DIR}"

mkdir -p "${TMPDIR}"

case "${ACTION}" in
'' | --pre)
	do_default "${ORIGINAL_ARGS[@]}"
	;;
watch)
	do_default_watch
	;;
install)
	go_home
	exec bash ../install-cli-tool.sh
	;;
upgrade)
	do_upgrade
	;;
refresh)
	do_refresh "$@"
	;;
rm)
	if [[ -z ${1-} ]]; then
		usage >&2
		die "missing 1 argument"
	fi
	do_rm "$1"
	;;
ls)
	do_ls "$@"
	;;
start | restart | stop | reload | reset-failed | status | enable | disable)
	if [[ $# -gt 0 ]]; then
		die "this command is to control ALL enabled service, not some of them"
	fi
	do_ls enabled >/dev/null
	if [[ -n ${#LIST_RESULT[@]} ]]; then
		systemctl "${ACTION}" "${LIST_RESULT[@]}"
	fi
	;;
log)
	do_log "$@"
	;;
logs)
	do_logs "$@"
	;;
abort)
	systemctl list-units '*.pod@.service' '*.pod.service' --all --no-pager --no-legend | grep activating \
		| awk '{print $1}' | mapfile -t LIST_RESULT

	if [[ -n ${#LIST_RESULT[@]} ]]; then
		systemctl stop "${LIST_RESULT[@]}"
	fi
	;;
attach)
	do_attach "$@"
	;;
nsenter)
	do_nsenter "$@"
	;;
pstree)
	do_pstree "$@"
	;;
pull)
	do_pull "$@"
	;;
deps)
	do_deps "$@"
	;;
*)
	usage
	die "unknown action: ${ACTION}"
	;;
esac
