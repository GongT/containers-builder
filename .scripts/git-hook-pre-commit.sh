#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."

function hash_every_systemd_plugin() {
	set -Eeuo pipefail
	cd "staff/systemd-filesystem"
	mapfile -d '' -t ITEMS < <(find . -maxdepth 1 -mindepth 1 -type d -print0)
	for ITEM in "${ITEMS[@]}"; do
		NAME=$(basename "${ITEM}")
		NEW_HASH=$(hash_files "${ITEM}" | md5sum -b | awk '{print $1}')
		OLD_HASH=$(cat "${ITEM}/version.txt" || true)
		if [[ ${NEW_HASH} != "${OLD_HASH}" ]]; then
			echo "systemd组件${NAME}哈希变化: ${OLD_HASH} -> ${NEW_HASH}" >&2
			printf "%s" "${NEW_HASH}" >"${ITEM}/version.txt"
		else
			echo "systemd组件${NAME}哈希未变化: ${OLD_HASH}" >&2
		fi
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
