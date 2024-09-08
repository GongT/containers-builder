#!/usr/bin/env bash
set -Eeuo pipefail

function debug() {
	echo "{wait-run} $*" >&2
}
function critical_die() {
	debug "$*"
	exit 233
}
function die() {
	debug "$*"
	exit 1
}
