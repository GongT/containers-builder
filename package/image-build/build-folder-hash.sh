#!/usr/bin/env bash

function hash_path() {
	local F=$1
	tar c --owner=0 --group=0 --mtime='UTC 2000-01-01' --sort=name -C "${F}" .
}
function fast_hash_path() {
	git ls-tree -r HEAD "$@"
}
function hash_current_folder() {
	info_note "hashing dir: ${CURRENT_DIR}"
	hash_path "${CURRENT_DIR}" | md5sum | awk '{print $1}'
}
