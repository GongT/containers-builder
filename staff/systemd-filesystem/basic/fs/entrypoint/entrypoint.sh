#!/bin/bash

log "arguments: $# - $*"

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS

if [[ ${IN_DEBUG_MODE-} == yes ]]; then
	log "debug mode detected"
	systemctl enable console-getty.service
	export IN_DEBUG_MODE
fi

if [[ -e ${NOTIFY_SOCKET-not exists} ]]; then
	export __NOTIFY_SOCKET__="${NOTIFY_SOCKET}"
	echo "__NOTIFY_SOCKET__=${NOTIFY_SOCKET}" >>/run/.userenvironments
	systemd-notify "--status=system boot up"
	echo "NOTIFY_SOCKET=${NOTIFY_SOCKET}" >>/root/.bashrc
	log "NOTIFY_SOCKET=${NOTIFY_SOCKET}"
else
	log "NOTIFY_SOCKET is not exists, disable success notify service."
	systemctl disable success.service notify-stop.service
	systemctl mask success.service notify-stop.service
	rm -f /usr/local/lib/systemd/system/multi-user.target.d/require-success.conf
fi
unset NOTIFY_SOCKET

env | grep -vE '^(SHLVL|PATH|_|container_uuid)=' >>/run/.userenvironments

CONTAINER_DIGIST_LONG=$(grep -F .containerenv /proc/self/mountinfo | grep -oE '[0-9a-f]{64}' || true)
CONTAINER_DIGIST_SHORT="$(echo "${CONTAINER_DIGIST_LONG}" | grep -oE '^[0-9a-f]{12}')"

printf 'CONTAINER_DIGIST_LONG=%s\n' "${CONTAINER_DIGIST_LONG}" >>/etc/environment
printf 'CONTAINER_DIGIST_SHORT=%s\n' "${CONTAINER_DIGIST_SHORT}" >>/etc/environment
printf 'CONTAINER_ID=%s\n' "${CONTAINER_ID-}" >>/etc/environment

# this variable is set by `podman --systemd=always`, 32 digits
echo "${container_uuid-"debugger container $RANDOM"}" >/etc/machine-id
cat /etc/machine-id >/run/machine-id

log "prestart:"
while read -d '' -r FILE; do
	log "    execute script: ${FILE}"
	source "${FILE}"
done < <(find /entrypoint/prestart.d -maxdepth 1 -type f -print0 | sort | grep -vF README.md)
log "prestart complete"

#####
log "CONTAINER_ID=${CONTAINER_ID-*not set*}"
log "CONTAINER_DIGIST_SHORT=${CONTAINER_DIGIST_SHORT}"
log "container_uuid=${container_uuid}"
#####

if [[ $* == '--systemd' || $# -eq 0 ]]; then
	log "executing systemd!"
	# capsh --print
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
fi

if [[ $* == 'bash' ]]; then
	log "hello!"
	export DEBUG_SHELL=yes
	set -- bash --login -i
fi

exec "$@"
