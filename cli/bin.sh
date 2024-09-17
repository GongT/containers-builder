#!/bin/bash

source "../package/include.sh"

if [[ $# -ge 1 ]]; then
	ACTION=${1-}
	shift
else
	ACTION=""
fi

if [[ ${UID} -eq 0 ]]; then
	declare -xr SCRIPTS_DIR="/usr/local/libexec/image-builder-cli"
	declare -r SYSTEM_UNITS_DIR="/usr/local/lib/systemd/system"
else
	declare -xr SCRIPTS_DIR="${HOME}/.local/libexec/image-builder-cli"
	declare -r SYSTEM_UNITS_DIR="${HOME}/.config/systemd/user"
	declare -r SYSTEMCTL=$(command -v systemctl)
	function systemctl() {
		"${SYSTEMCTL}" --user "$@"
	}
fi

cd "${SCRIPTS_DIR}"

source cli-lib/common.sh
source cli-lib/table.sh
source cli-lib/usage.sh
for i in cli-lib/act_*.sh; do
	# shellcheck disable=SC1090
	source "${i}"
done

case "${ACTION}" in
'')
	do_default
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
	do_pull_all "$@"
	;;
deps)
	do_deps "$@"
	;;
*)
	usage
	die "unknown action: ${ACTION}"
	;;
esac
