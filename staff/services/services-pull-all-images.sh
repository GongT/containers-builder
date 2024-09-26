#!/usr/bin/env bash

source "../../package/include.sh"
use_normal

grep -lFR '[X-Containers]' "${SYSTEM_UNITS_DIR}" | while read -r SRV_FILE; do
	info "\e[7;38;5;3m  $SRV_FILE  \e[0m"

	TARGET_SCRIPT_DIR=$(grep -F SCRIPTS_DIR= "${SRV_FILE}" | head -n1 | cut -d= -f2-)
	if [[ -z ${TARGET_SCRIPT_DIR} ]]; then
		info_error "missing SCRIPTS_DIR"
		continue
	fi

	if env -i "SKIP_REMOVE=yes" "${TARGET_SCRIPT_DIR}/pull-image" always; then
		info_success "\e[38;5;10mDone!\e[0m"
	else
		info_error "\e[38;5;9mFailed!\e[0m"
	fi
done

exit 0
