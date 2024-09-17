#!/usr/bin/env bash

function do_deps() {
	print_services_status_table "services.target" "services-pre.target" "${CONTROL_SERVICES[@]}"
}
