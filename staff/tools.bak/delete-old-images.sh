#!/usr/bin/env bash

set -Eeuo pipefail

echo "removing images:" >&2
podman images \
	| grep --fixed-strings '<none>' \
	| awk '{print $3}' \
	| xargs --no-run-if-empty --verbose --no-run-if-empty \
		podman rmi || true
