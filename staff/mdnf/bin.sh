#!/usr/bin/env bash

set -Eeuo pipefail

cd /

mkdir -p /install-root/etc/dnf
cp /etc/dnf/dnf.conf /install-root/etc/dnf/dnf.conf

TO_UNMOUNT=()

bind_fs() {
	local FS=$1
	rm -rf "/install-root$FS"
	mkdir -p "/install-root$FS" "$FS"
	mount --bind "$FS" "/install-root$FS"
	TO_UNMOUNT+=("/install-root$FS")
}

if ! command -v "mount" &>/dev/null; then
	dnf install -y util-linux-core
fi
bind_fs /var/lib/dnf/repos
bind_fs /var/cache/dnf

_exit() {
	R=$?

	umount "${TO_UNMOUNT[@]}"

	DIRS_SHOULD_EMPTY=(/install-root/var/log /install-root/tmp)
	rm -rf "${DIRS_SHOULD_EMPTY[@]}"
	mkdir -p "${DIRS_SHOULD_EMPTY[@]}"
	chmod 0777 "${DIRS_SHOULD_EMPTY[@]}"

	echo "dnf script returned $R" >&2
	exit $R
}

trap _exit EXIT

if ! [[ ${ACTION:-} ]]; then
	ACTION="install"
fi

dnf() {
	echo -e "\e[2m + /usr/bin/dnf --nodocs -y --releasever=/ --installroot=/install-root $*\e[0m" >&2
	/usr/bin/dnf --nodocs -y --releasever=/ --installroot=/install-root "$@"
}

# dnf clean expire-cache
# dnf makecache
dnf "$ACTION" "${PACKAGES[@]}"

if [[ $ACTION == install ]] && command -v busybox &>/dev/null; then
	echo "installing busybox..." &>/dev/null
	busybox --install /bin
fi

cd /install-root
