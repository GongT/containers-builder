#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_systemd() {
	sdnotify --status="wait:output"

	__run
}
