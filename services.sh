#!/usr/bin/env bash

declare -r SERVICES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/services"

function _use_common_copy() {
	local SRV="$1" ARG="${2:-}" SCRIPT
	local SRV_FILE

	if [[ "$ARG" ]]; then
		SRV_FILE="$SRV@.service"
	else
		SRV_FILE="$SRV.service"
	fi

	install_script "${SERVICES_DIR}/common_service_library.sh" >/dev/null
	SCRIPT=$(install_script "${SERVICES_DIR}/${SRV}.sh")

	cat "${SERVICES_DIR}/${SRV_FILE}" \
		| sed "s#__SCRIPT__#$SCRIPT#g" \
		| fix_old_systemd \
		| write_file_share "/usr/lib/systemd/system/$SRV_FILE"
}

function fix_old_systemd() {
	local V CatchData
	CatchData=$(cat)

	if ! echo "$CatchData" | grep -qi 'Type=oneshot'; then
		echo "$CatchData"
		return
	fi

	V=$(systemctl --version | grep -oE 'systemd [0-9]+' | sed 's#systemd ##')
	if [[ $V -gt 244 ]]; then
		echo "$CatchData"
	else
		echo "$CatchData" | sed -E "s/^Restart=/### systemd $V not support Restart=/g"
	fi
}

function use_common_timer() {
	local NAME="$1" SCRIPT
	_use_common_copy "$NAME"

	TIMER_FILE="$NAME.timer"
	SCRIPT=$(install_script "${SERVICES_DIR}/${NAME}.sh")

	cat "${SERVICES_DIR}/${TIMER_FILE}" \
		| sed "s#__SCRIPT__#$SCRIPT#g" \
		| write_file_share "/usr/lib/systemd/system/$TIMER_FILE"
	unit_unit Requires "$NAME.timer"

	# systemctl enable "$NAME.timer"
}

function use_common_service() {
	_use_common_copy "$@"

	local SRV="$1" ARG="${2:-}" SRV_NAME
	if [[ "$ARG" ]]; then
		SRV_NAME="$SRV@$ARG.service"
	else
		SRV_NAME="$SRV.service"
	fi
	unit_unit After "$SRV_NAME"
	unit_unit Requires "$SRV_NAME"
}
