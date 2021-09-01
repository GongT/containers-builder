#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd cli

PWD="$(pwd)"

rsync -avh "$PWD/cli-lib" /usr/share/scripts --delete

echo "$PWD" > /usr/share/scripts/cli-home

if [[ -L /usr/local/bin/ms ]]; then
	unlink /usr/local/bin/ms
fi
cp bin.sh /usr/local/bin/ms
chmod a+x /usr/local/bin/ms
