#!/usr/bin/env bash

declare -r SERVICES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/services"
_COMMON_FILE_INSTALL=

function _copy_common_static_unit() {
	local FILE=$1
	write_file_share "/usr/lib/systemd/system/$FILE" "$(<"${SERVICES_DIR}/${FILE}")"
}
function install_common_system_support() {
	if is_uninstalling; then
		: # no reduce method now
	elif [[ ! $_COMMON_FILE_INSTALL ]]; then
		_COMMON_FILE_INSTALL=yes

		install_script "${SERVICES_DIR}/common_service_library.sh" >/dev/null

		_copy_common_static_unit services-entertainment.slice
		_copy_common_static_unit services-infrastructure.slice
		_copy_common_static_unit services-normal.slice
		_copy_common_static_unit services.slice
		_copy_common_static_unit services.timer
		_copy_common_static_unit services-pre.target
		_copy_common_static_unit services.target
		_copy_common_static_unit containers.target
		install_common_script_service wait-dns-working
		install_common_script_service cleanup-stopped-containers
		install_common_script_service services-boot
		_copy_common_static_unit services-spin-up.service
		edit_system_service dnsmasq create-dnsmasq-config
		service_dropin systemd-networkd alias-nameserver.conf

		install_common_script_service containers-ensure-health
		_copy_common_static_unit containers-ensure-health.timer

		if ! systemctl is-enabled --quiet services.timer; then
			systemctl daemon-reload
			systemctl enable services.timer
		fi
	fi
}
function install_common_script_service() {
	local SRV="$1" ARG="${2-}" SCRIPT
	local SRV_FILE

	if [[ "$ARG" ]]; then
		SRV_FILE="$SRV@.service"
	else
		SRV_FILE="$SRV.service"
	fi

	SCRIPT=$(install_script "${SERVICES_DIR}/${SRV}.sh")

	cat "${SERVICES_DIR}/${SRV_FILE}" \
		| sed "s#__SCRIPT__#$SCRIPT#g" \
		| write_file_share "/usr/lib/systemd/system/$SRV_FILE"
}

function use_common_timer() {
	local NAME="$1" SCRIPT
	install_common_script_service "$NAME"

	TIMER_FILE="$NAME.timer"

	cat "${SERVICES_DIR}/${TIMER_FILE}" \
		| write_file_share "/usr/lib/systemd/system/$TIMER_FILE"
	unit_unit Requires "$NAME.timer"

	# systemctl enable "$NAME.timer"
}

function use_common_service() {
	local DEP=
	if [[ $1 == '+' ]] || [[ $1 == '!' ]]; then
		DEP=$1
		shift
	fi

	install_common_script_service "$@"

	local SRV="$1" ARG="${2-}" SRV_NAME
	if [[ "$ARG" ]]; then
		SRV_NAME="$SRV@$ARG.service"
	else
		SRV_NAME="$SRV.service"
	fi
	if [[ $DEP == '+' ]]; then
		unit_unit Requires "$SRV_NAME"
	elif [[ $DEP == '!' ]]; then
		unit_unit Requires "$SRV_NAME"
		unit_unit After "$SRV_NAME"
	else
		unit_unit Wants "$SRV_NAME"
	fi
}

function service_dropin() {
	local SRV="${1}.service" OVERWRITE="${2}" ONAME
	local FOLDER="/usr/lib/systemd/system/$SRV.d"
	mkdir -p "$FOLDER"

	ONAME=$(basename "$OVERWRITE" .conf)

	cat "${SERVICES_DIR}/${OVERWRITE}" \
		| write_file_share "$FOLDER/$ONAME.conf"

}
function edit_system_service() {
	local SRV="$1" OVERWRITE="${2}" SCRIPT

	install_common_system_support
	SCRIPT=$(install_script "${SERVICES_DIR}/${OVERWRITE}.sh")

	if [[ $SRV != *".service" ]]; then
		SRV="$SRV.service"
	fi
	local FOLDER="/usr/lib/systemd/system/$SRV.d"
	mkdir -p "$FOLDER"

	cat "${SERVICES_DIR}/${OVERWRITE}.service" \
		| sed "s#__SCRIPT__#$SCRIPT#g" \
		| write_file_share "$FOLDER/$OVERWRITE.conf"
}
