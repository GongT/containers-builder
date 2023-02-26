#!/usr/bin/env bash

function do_default() {
	if systemctl is-active services-pre.target -q ; then
		mapfile -t SERVICES < <(do_ls)
		print_services_status_table "${SERVICES[@]}" 
	else
		print_services_status_table "services.target" "services-pre.target" "${CONTROL_SERVICES[@]}"
	fi
}
