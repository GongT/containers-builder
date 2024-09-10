#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -xr PROJECT_NAME="image-builder-cli"
source "functions.sh"
cd cli

mkdir -p "$SCRIPTS_DIR"
rsync --itemize-changes --archive --human-readable "$PWD/cli-lib" "$SCRIPTS_DIR" --delete
rsync --itemize-changes --archive --human-readable bin.sh "$BINARY_DIR/ms"

echo "$PWD" >"$SCRIPTS_DIR/cli-home"

chmod a+x "$BINARY_DIR/ms"

echo "binary installed to $BINARY_DIR/ms"
echo "library installed to $SCRIPTS_DIR"
