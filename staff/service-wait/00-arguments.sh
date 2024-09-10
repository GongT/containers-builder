#!/usr/bin/env bash
set -Eeuo pipefail

declare -a ARGS=()
function add_argument() {
	ARGS=("$@" "${ARGS[@]}")
}
# ARGS+=("--attach=stdin,stdout,stderr")
# ARGS+=("--log-level=debug")

function make_arguments() {
	detect_host_ip

	if [[ -n "${INVOCATION_ID:-}" ]]; then
		add_argument "--label=systemd.service.invocation_id=${INVOCATION_ID}"
	fi

	for i; do
		if [[ ${i} == "--dns=h.o.s.t" ]]; then
			if ! [[ -n "${HOST_IP}" ]]; then
				critical_die "Try to use h.o.s.t when network type is ${NETWORK_TYPE}, this is currently not supported."
			fi
			ARGS+=("--dns=${HOST_IP}")
		elif [[ ${i} == "--dns=p.a.s.s" ]]; then
			dns_pass argument
		elif [[ ${i} == "--dns-env=p.a.s.s" ]]; then
			dns_pass env
		elif [[ ${i} == "--dns="* ]]; then
			if ip route get "${i#--dns=}" &>/dev/null; then
				ARGS+=("${i}")
			else
				dns_resolve argument "${i#--dns=}"
			fi
		elif [[ ${i} == "--dns-env="* ]]; then
			if ip route get "${i#--dns-env=}" &>/dev/null; then
				ARGS+=("${i}")
			else
				dns_resolve env "${i#--dns-env=}"
			fi
		else
			ARGS+=("${i}")
		fi
	done

	dns_finalize
}
