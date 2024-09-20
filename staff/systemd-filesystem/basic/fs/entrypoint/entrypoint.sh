#!/bin/bash

echo "[entrypoint.sh]: arguments: $# - $*"
echo "[entrypoint.sh]: environments: (save to /run/.userenvironments)"

{
	if [[ "${RESOLVE_OPTIONS-}" ]]; then
		echo "options $RESOLVE_OPTIONS"
	fi
	if [[ "${RESOLVE_SEARCH-}" ]]; then
		echo "search $RESOLVE_SEARCH"
	fi
	if [[ "${NSS-}" ]]; then
		mapfile -d ' ' -t NSS < <(echo "$NSS")
		for NS in "${NSS[@]}"; do
			echo "nameserver $NS"
		done
	else
		echo "nameserver 8.8.8.8"
	fi
} >/etc/resolv.conf

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS

if [[ ${IN_DEBUG_MODE-} == yes ]]; then
	systemctl enable console-getty.service
fi

if [[ -e ${NOTIFY_SOCKET-not exists} ]]; then
	echo "__NOTIFY_SOCKET__=${NOTIFY_SOCKET}" >>/run/.userenvironments
	systemd-notify "--status=system boot up"
	echo "NOTIFY_SOCKET=${NOTIFY_SOCKET}" >>/root/.bashrc
else
	echo "NOTIFY_SOCKET is not exists, disable success notify service."
	systemctl disable success.service
	systemctl mask success.service
	rm -f /usr/local/lib/systemd/system/multi-user.target.d/require-success.conf
fi
unset NOTIFY_SOCKET

env | grep -vE '^(SHLVL|PATH|_|container_uuid)=' >>/run/.userenvironments

CONTAINER_DIGIST_LONG=$(grep -F .containerenv /proc/self/mountinfo | grep -oE '[0-9a-f]{64}' || true)
printf 'CONTAINER_DIGIST_LONG=%s\n' "${CONTAINER_DIGIST_LONG}" >>/etc/environment
printf 'CONTAINER_DIGIST_SHORT=%s\n' "$(echo "${CONTAINER_DIGIST_LONG}" | grep -oE '^[0-9a-f]{12}')" >>/etc/environment

# this variable is set by `podman --systemd=always`, 32 digits
echo "${container_uuid}" >/etc/machine-id
echo "${container_uuid}" >/run/machine-id

if [[ $* == '--systemd' ]]; then
	capsh --print
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
fi

if [[ $* == 'bash' ]]; then
	export DEBUG_SHELL=yes
	set -- bash --login -i
fi

exec "$@"
