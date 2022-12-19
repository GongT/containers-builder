#!/usr/bin/env bash

set -Eeuo pipefail

if command -v ms &>/dev/null; then
	ms pull
else
	echo "Warn: services common cli is not installed"
	exit 66
fi
