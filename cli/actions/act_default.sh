#!/usr/bin/env bash

function do_default() {
	if [[ ${1-} != --pre ]] && systemctl is-active services-pre.target -q; then
		local -a SERVICES
		do_ls | mapfile -t SERVICES
		print_services_status_table "${SERVICES[@]}"
	else
		print_services_status_table "${CONTROL_SERVICES[@]}"
	fi
	table_print
}

function do_default_watch() {
	trap 'exit 0' INT
	register_exit_handler reset_terminal

	if [[ ${1-} != --pre ]] && systemctl is-active services-pre.target -q; then
		local -a SERVICES
		do_ls | mapfile -t SERVICES

		tput smcup
		while true; do
			print_services_status_table "${SERVICES[@]}"
			DATA=$(table_print)
			printf '\ec%s\n' "${DATA}"
			sleep 1
		done
	else

		tput smcup
		while true; do
			print_services_status_table "${CONTROL_SERVICES[@]}"
			DATA=$(table_print)
			printf '\ec%s\n' "${DATA}"
			sleep 1
		done
	fi
}
