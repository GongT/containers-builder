#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."

function hash_every_systemd_plugin() {
	set -Eeuo pipefail
	cd "staff/systemd-filesystem"
	for ITEM in */; do
		hash_files "${ITEM}" | md5sum -b | awk '{print $1}' >"${ITEM}/version.txt"
	done
	git add ./*/version.txt
}

function x() {
	echo "$*" >&2
	"$@"
}

function hash_files() {
	local F=$1
	tar c --owner=0 --group=0 --mtime='UTC 2000-01-01' --sort=name --exclude=version.txt -C "${F}" .
}

git add .
(hash_every_systemd_plugin)
