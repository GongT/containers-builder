#!/usr/bin/env bash

declare -ra CONTROL_SERVICES=(wait-all-fstab.service create-dnsmasq-config.service wait-dns-working.service containers-ensure-health.timer)
BIN_SRC_HOME=$(</usr/share/scripts/cli-home)

function die() {
	echo "$*" >&2
	exit 1
}

function do_ls() {
	{
		systemctl list-units --all --no-pager --no-legend --type=service '*.pod@*.service' '*.pod.service' | sed 's/●//g' | awk '{print $1}'
		systemctl list-unit-files --no-legend --no-pager --state=disabled --type=service '*.pod.service' | awk '{print $1}'
	} | sed -E 's/\.service$//g' | sort
}

function go_home() {
	cd "$BIN_SRC_HOME" || die "failed chdir to containers source folder ($BIN_SRC_HOME)"
}
