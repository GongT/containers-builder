#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_port() {
	local -r PROTOCOL=$1 PORT=$2
}
