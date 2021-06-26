#!/usr/bin/env bash

export http_proxy='' https_proxy='' all_proxy='' HTTP_PROXY='' HTTPS_PROXY='' ALL_PROXY=''
{
	echo "============================== Action =============================="
	echo "$*"
	echo "===================================================================="
} >&2

for I in $(seq 1 3); do
	echo "============================== try $I ==============================" >&2
	"$@"
	RET=$?
	echo "============================== try $I exit $RET ====================" >&2
	if [[ $RET -eq 0 ]]; then
		exit 0
	fi
done

if ! [[ "${PROXY:-}" ]]; then
	echo "::: Failed without proxy, no proxy to try :::" >&2
	exit $RET
fi

echo "::: Failed without proxy, retry with proxy ($PROXY) :::" >&2

export http_proxy="$PROXY"
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
