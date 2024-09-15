#!/usr/bin/bash

TO_UNMOUNT=()
function shadow_dir() {
	local DIR=$(realpath -m "/install-root/$1")
	rm -rf /tmp/shadow.dir
	if [[ -d ${DIR} ]]; then
		cp -r "${DIR}" /tmp/shadow.dir
	else
		mkdir "${DIR}"
	fi
	mount -t tmpfs tmpfs "${DIR}"
	if [[ -d /tmp/shadow.dir ]]; then
		cp -r /tmp/shadow.dir/. "${DIR}"
	fi
	TO_UNMOUNT+=("${DIR}")
}
function tmpfs() {
	local DIR=$(realpath -m "/install-root/$1")
	mount --mkdir -t tmpfs tmpfs "${DIR}"
	TO_UNMOUNT+=("${DIR}")
}
function make_bind_mount() {
	local -r ROOT="$1"
	tmpfs run
	tmpfs var/log
	for mp in sys proc dev; do
		mount --mkdir --bind "/${mp}" "${ROOT}/${mp}"
		TO_UNMOUNT+=("${ROOT}/${mp}")
	done
}

function _handle_exit() {
	if [[ ${#TO_UNMOUNT[@]} -gt 0 ]]; then
		info_note " * unmounts: ${TO_UNMOUNT[*]}"
		umount "${TO_UNMOUNT[@]}"
	fi
}
register_exit_handler _handle_exit
