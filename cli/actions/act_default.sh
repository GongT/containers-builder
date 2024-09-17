#!/usr/bin/env bash

function do_default() {
	if [[ ${1-} != --pre ]] && systemctl is-active services-pre.target -q; then
		local -a SERVICES
		do_ls | mapfile -t SERVICES
		print_services_status_table "${SERVICES[@]}"
	else
		print_services_status_table "${CONTROL_SERVICES[@]}"
	fi
}
