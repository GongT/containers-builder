#!/bin/bash

declare -r FORCE_CONTINUE_FILE='/run/force-continue-once'

STILL_NUM=$(last reboot -F -n 2 | grep -o still | wc -l)
if [[ ${STILL_NUM} -gt 1 ]]; then
	echo "Unexpected shutdown detected, service startup canceled." >&2
	if [[ -e ${FORCE_CONTINUE_FILE} ]]; then
		echo "Force continue!"
		unlink "${FORCE_CONTINUE_FILE}"
		exit 0
	else
		echo "Unexpected shutdown detected, service startup canceled." >&2
		echo "Unexpected shutdown detected, service startup canceled." >&2
		echo "Must inspect what's happening by hand. After that, run:"
		echo "	  touch ${FORCE_CONTINUE_FILE}"
		echo "	  systemctl start services-boot.service services.target"

		exit 1
	fi
else
	echo "last reboot clean, continue start..."
	exit 0
fi
