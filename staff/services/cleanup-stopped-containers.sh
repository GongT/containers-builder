#!/usr/bin/env bash

echo "cleaning stopped containers:"
podman ps -a --noheading \
	| grep -vF 'Up ' \
	| awk '{print $1}' \
	| xargs --no-run-if-empty --verbose --no-run-if-empty podman rm

echo "removing unused images:"
podman image list --noheading \
	| grep --fixed-strings '<none>' \
	| awk '{print $3}' \
	| xargs --no-run-if-empty -t podman image rm || true

exit 0
