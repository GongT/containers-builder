#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ge 1 ]]; then
	ACTION=${1:-}
	shift
else
	ACTION=""
fi

cd /usr/share/scripts

source cli-lib/common.sh
source cli-lib/usage.sh
for i in cli-lib/act_*.sh; do
	# shellcheck disable=SC1090
	source "$i"
done

case "$ACTION" in
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
	if ! [[ "${1:-}" ]]; then
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
	do_ls enabled | xargs --no-run-if-empty -t systemctl "$ACTION"
	;;
log)
	do_log "$@"
	;;
logs)
	do_logs "$@"
	;;
abort)
	systemctl list-units '*.pod@.service' '*.pod.service' --all --no-pager --no-legend | grep activating \
		| awk '{print $1}' | xargs --no-run-if-empty -t systemctl stop
	;;
attach)
	do_attach "$@"
	;;
pull)
	do_pull_all "$@"
	;;
*)
	usage
	die "unknown action: $ACTION"
	;;
esac
