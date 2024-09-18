#!/usr/bin/env bash

function _ls_all_with_cache() {
	local -r CACHE_FILE="${PRIVATE_CACHE}/remember-service-list.txt"
	if [[ -e ${CACHE_FILE} ]]; then
		cat "${CACHE_FILE}"
		return
	fi

	(
		flock --exclusive --nonblock 1 || die "failed acquire file lock."

		printf 'Analyzing system services...\r' >&2

		{
			systemctl list-units --all --no-pager --no-legend --type=service 2>/dev/null | sed 's/●//g' | awk '{print $1}'
			systemctl list-unit-files --no-legend --no-pager --type=service 2>/dev/null | awk '{print $1}'
		} | sort | uniq | while read -r NAME; do
			printf 'Analyzing %s...\e[K\r' "${NAME}" >&2
			if systemctl cat "${NAME}" 2>/dev/null | grep -qF '[X-Containers]'; then
				echo "${NAME%.service}"
			fi
		done >"${CACHE_FILE}"

		printf '\e[K' >&2
	) >"${CACHE_FILE}"

	cat "${CACHE_FILE}"
}

function do_ls() {
	local -r STATE_FILTER=${1-}
	local NAME

	_ls_all_with_cache | while read -r NAME; do
		if [[ ${STATE_FILTER} == enabled ]]; then
			if [[ ${NAME} == *@.service ]] || ! systemctl is-enabled -q "${NAME}"; then
				continue
			fi
		elif [[ ${STATE_FILTER} == disabled ]]; then
			if [[ ${NAME} == *@.service ]] || systemctl is-enabled -q "${NAME}"; then
				continue
			fi
		elif [[ -n ${STATE_FILTER} ]]; then
			die "invalid arg: $*"
		fi

		echo "${NAME}"
	done
}

function go_home() {
	cd "${COMMON_LIB_ROOT}/cli" || die "failed chdir to containers source folder ($BIN_SRC_HOME)"
}

function expand_service_file() {
	local NAME_HINT=${1-}
	_ls_all_with_cache | while read -r NAME; do
		if [[ -z ${NAME_HINT} || ${NAME} == "${NAME_HINT}"* ]]; then
			if [[ ${NAME} == *@* ]]; then
				echo "${NAME%@*}@.service"
			else
				echo "${NAME}.service"
			fi
		fi
	done
}
function expand_service_name() {
	local NAME_HINT=$1
	_ls_all_with_cache | while read -r NAME; do
		if [[ ${NAME} == "${NAME_HINT}"* ]]; then
			echo "${NAME}"
		fi
	done
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

function is_service_file_container() {
	grep -qF '[X-Containers]' "$1"
}

function filter_service_file_comment() {
	local READING=0 FIND_NAME=${1-}
	while read -r LINE; do
		if [[ ${LINE} == '['* ]]; then
			if [[ ${READING} -eq 1 ]]; then
				return
			elif [[ ${LINE} == '[X-Containers]' ]]; then
				READING=1
			fi
		elif [[ ${READING} -eq 1 && -n ${LINE} ]]; then
			if [[ -n ${FIND_NAME} ]]; then
				if [[ ${LINE} == "${FIND_NAME}="* ]]; then
					echo "${LINE:${#FIND_NAME}+1}"
					return
				fi
			else
				echo "${LINE}"
			fi
		fi
	done
}
