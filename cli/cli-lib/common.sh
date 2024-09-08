#!/usr/bin/env bash

declare -ra CONTROL_SERVICES=(wait-dns-working.service containers-ensure-health.timer services-boot.service)
BIN_SRC_HOME=$(</usr/share/scripts/cli-home)
declare -r SYSTEM_UNITS_DIR="/usr/lib/systemd/system"

function die() {
	echo "$*" >&2
	exit 1
}

function do_ls() {
	local US U

	mapfile -t US < <(
		{
			systemctl list-units --all --no-pager --no-legend --type=service '*.pod@*.service' '*.pod.service' | sed 's/●//g' | awk '{print $1}'
			systemctl list-unit-files --no-legend --no-pager --type=service '*.pod.service' | awk '{print $1}'
		} | sed -E 's/\.service$//g' | sort | uniq
	)
	if [[ $# -eq 0 ]]; then
		for U in "${US[@]}"; do
			echo "$U"
		done
	elif [[ ${1:-} == 'enabled' ]]; then
		for U in "${US[@]}"; do
			if systemctl is-enabled -q "${U}.service"; then
				echo "$U"
			fi
		done
	elif [[ ${1:-} == 'disabled' ]]; then
		for U in "${US[@]}"; do
			if ! systemctl is-enabled -q "${U}.service"; then
				echo "$U"
			fi
		done
	else
		die "invalid arg: $*"
	fi
}

function go_home() {
	cd "$BIN_SRC_HOME" || die "failed chdir to containers source folder ($BIN_SRC_HOME)"
}

function get_service_file() {
	local NAME_HINT=$1
	systemctl list-unit-files --no-legend --no-pager --type=service "$NAME_HINT*" | grep pod | awk '{print $1}'
}

function get_container_by_service() {
	local R
	R=$(systemctl show "$1" --property=Environment | grep -oP 'CONTAINER_ID=\S+' || true)
	if [[ $R ]]; then
		echo "${R##CONTAINER_ID=}"
	else
		echo "missing container $1" >&2
		return 1
	fi
}
