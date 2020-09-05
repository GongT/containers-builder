#!/usr/bin/env bash

for I in $(seq 1 3); do
	echo "============================== try $I ==============================" >&2
	"$@"
	RET=$?
	echo "============================== try $I exit $RET ====================" >&2
	if [[ $RET -eq 0 ]]; then
		exit 0
	fi
done

exit $RET
