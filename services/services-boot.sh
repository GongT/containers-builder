#!/bin/bash

STILL_NUM=$(last reboot -F -n 2 | grep -o still | wc -l)
if [[ $STILL_NUM -gt 1 ]]; then
	echo -e "Unexpected shutdown detected, service startup canceled." >&2
	echo -e "Unexpected shutdown detected, service startup canceled." >&2
	echo -e "Unexpected shutdown detected, service startup canceled." >&2
	exit 1
else
	echo "last reboot clean, continue start..."
	exit 0
fi
