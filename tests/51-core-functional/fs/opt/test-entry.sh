#!/usr/bin/env bash

set -Eeuo pipefail

echo -e "\x1B[38;5;9mThis is entrypoint\x1B[0m"
echo "your argument is: $*"

echo "environments:"
env
echo "-----"

trap "echo 'exit trap called'" EXIT
trap "echo 'got sigint'; exit 0" SIGINT

while true; do
	sleep 5s
	echo "wakeup at $(date)"
done
