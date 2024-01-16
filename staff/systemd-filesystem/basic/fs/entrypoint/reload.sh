#!/usr/bin/env bash

set -Eeuo pipefail

echo "reloading..."

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd reload.d

for I in *; do
	if [[ $I == "README.md" ]]; then
		continue
	fi

	if [[ -s $I ]]; then
		echo "execute $I" || true
		bash "$I"
	else
		echo "systemctl reload $I"
		systemctl reload --no-block "$I" || true
	fi
done
echo "reload complete"
