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
	do_install
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
	do_ls
	;;
start | restart | stop | reload | reset-failed | status | enable | disable)
	do_ls | xargs --no-run-if-empty -t systemctl "$ACTION"
	;;
log)
	IARGS=() NARGS=()
	for I; do
		if [[ $I == -f ]]; then
			NARGS+=(-f)
		else
			IARGS+=("$I")
		fi
	done

	if [[ ${#IARGS[@]} -ne 1 ]]; then
		die "must 1 argument"
	fi
	V=${IARGS[0]}
	if [[ $V != *.pod ]] && ! [[ $V != *.pod@* ]]; then
		V+=".pod"
	fi
	IID=$(systemctl show -p InvocationID --value "$V.service")
	echo "InvocationID=$IID"
	journalctl "${NARGS[@]}" "_SYSTEMD_INVOCATION_ID=$IID"
	;;
logs)
	LARGS=() NARGS=()
	for I; do
		if [[ $I == -f ]]; then
			NARGS+=(-f)
		else
			LARGS+=(-u "$I")
		fi
	done
	if [[ ${#LARGS[@]} -eq 0 ]]; then
		for i in $(do_ls); do
			LARGS+=("-u" "$i")
		done
	fi
	journalctl "${LARGS[@]}" "${NARGS[@]}"
	;;
abort)
	systemctl list-units '*.pod@.service' '*.pod.service' --all --no-pager --no-legend | grep activating \
		| awk '{print $1}' | xargs --no-run-if-empty -t systemctl stop
	;;
attach)
	do_attach "$@"
	;;
pull)
	pull_all "$@"
	;;
*)
	usage
	die "unknown action: $ACTION"
	;;
esac
