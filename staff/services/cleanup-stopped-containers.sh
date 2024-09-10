#!/usr/bin/env bash

podman ps -a | tail -n +2 \
	| (grep -v Up || [[ $? == 1 ]]) \
	| awk '{print $1}' \
	| xargs --no-run-if-empty --verbose --no-run-if-empty podman rm

exit 0
