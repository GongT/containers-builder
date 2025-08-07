#!/usr/bin/env bash

do_mount() {
	if [[ $# -eq 0 ]]; then
		die "missing arguments"
	fi

	CONTAINER_HINT="$1"
	CONTAINER=$(find_one_container_by_hint "${CONTAINER_HINT}" || die "can not find container by '${CONTAINER_HINT}'")

	MNT=$(podman mount "${CONTAINER}")

	exec unshare --mount-proc --pid --fork --propagation=private --wd="${ORIGINAL_PWD}" bash "${BASH_SOURCE[0]}" "__mount_inner__" "${MNT}"
}

do_mount_inner() {
	local MNT="$1"
	echo "mounting ${MNT} on /mnt ..."
	mount --rbind "${MNT}" /mnt

	cd "${ORIGINAL_PWD}"
	exec bash --login -i
}
