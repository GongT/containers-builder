#!/usr/bin/env bash

SERVICES_DIR="$COMMON_LIB_ROOT/staff/services"
declare -r SERVICES_DIR
_COMMON_FILE_INSTALL=

function _copy_common_static_unit() {
	local FILE=$1 NAME="${2-"$(basename "$1")"}"
	copy_file "${SERVICES_DIR}/${FILE}" "${SYSTEM_UNITS_DIR}/${NAME}"
}
function install_common_system_support() {
	if is_uninstalling; then
		: # no reduce method now
	elif [[ -z ${_COMMON_FILE_INSTALL} ]]; then
		_COMMON_FILE_INSTALL=yes

		install_script "${SERVICES_DIR}/common_service_library.sh" >/dev/null

		_copy_common_static_unit services-entertainment.slice
		_copy_common_static_unit services-infrastructure.slice
		_copy_common_static_unit services-normal.slice
		_copy_common_static_unit services.slice
		install_common_script_service wait-dns-working
		install_common_script_service cleanup-stopped-containers
		install_common_script_service containers-ensure-health
		_copy_common_static_unit containers-ensure-health.timer

		if is_root; then
			_copy_common_static_unit services.timer
			_copy_common_static_unit services@root.target services.target
			_copy_common_static_unit services-pre.target
			_copy_common_static_unit containers.target
			_copy_common_static_unit services-spin-up.service
			install_common_script_service services-boot
			service_dropin systemd-networkd alias-nameserver.conf
			edit_system_service dnsmasq create-dnsmasq-config

			if ! systemctl is-enabled --quiet services.timer; then
				systemctl daemon-reload
				systemctl enable services.timer
			fi
		else
			_copy_common_static_unit services@user.target services.target

			if ! systemctl is-enabled --quiet services.target; then
				systemctl daemon-reload
				systemctl enable services.target
			fi
		fi
	fi
}
function install_common_script_service() {
	local SRV="$1" ARG="${2-}" SCRIPT
	local SRV_FILE

	if [[ -n ${ARG} ]]; then
		SRV_FILE="${SRV}@.service"
	else
		SRV_FILE="${SRV}.service"
	fi

	SCRIPT=$(install_script "${SERVICES_DIR}/${SRV}.sh")

	cat "${SERVICES_DIR}/${SRV_FILE}" \
		| sed "s#__SCRIPT__#${SCRIPT}#g" \
		| output_file "${SYSTEM_UNITS_DIR}/${SRV_FILE}"
}

function use_common_timer() {
	local NAME="$1" SCRIPT
	install_common_script_service "${NAME}"

	TIMER_FILE="${NAME}.timer"

	_copy_common_static_unit "${TIMER_FILE}"
	unit_unit Requires "${TIMER_FILE}"
}

function use_common_service() {
	local DEP=
	if [[ $1 == '+' ]] || [[ $1 == '!' ]]; then
		DEP=$1
		shift
	fi

	install_common_script_service "$@"

	local SRV="$1" ARG="${2-}" SRV_NAME
	if [[ -n ${ARG} ]]; then
		SRV_NAME="${SRV}@${ARG}.service"
	else
		SRV_NAME="${SRV}.service"
	fi
	if [[ ${DEP} == '+' ]]; then
		unit_unit Requires "${SRV_NAME}"
	elif [[ ${DEP} == '!' ]]; then
		unit_unit Requires "${SRV_NAME}"
		unit_unit After "${SRV_NAME}"
	else
		unit_unit Wants "${SRV_NAME}"
	fi
}

function service_dropin() {
	local SRV="${1}.service" OVERWRITE="${2}" ONAME
	ONAME=$(basename "${OVERWRITE}" .conf)

	copy_file "${SERVICES_DIR}/${OVERWRITE}" "${SYSTEM_UNITS_DIR}/${SRV}.d/${ONAME}.conf"
}
function edit_system_service() {
	local SRV="$1" OVERWRITE="${2}" SCRIPT_FILE

	install_common_system_support
	SCRIPT_FILE=$(install_script "${SERVICES_DIR}/${OVERWRITE}.sh")

	if [[ ${SRV} != *".service" ]]; then
		SRV="${SRV}.service"
	fi
	local FOLDER=""

	cat "${SERVICES_DIR}/${OVERWRITE}.service" \
		| sed "s#__SCRIPT__#${SCRIPT_FILE}#g" \
		| output_file "${SYSTEM_UNITS_DIR}/${SRV}.d/${OVERWRITE}.conf"
}
