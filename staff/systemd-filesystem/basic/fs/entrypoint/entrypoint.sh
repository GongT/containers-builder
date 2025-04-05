#!/bin/bash

function log() {
	echo "[entry] $*" >&2
}

log "arguments: $# - $*"

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS

function exportenv() {
	local -r NAME=$1 VALUE=$2
	if [[ $# -ne 2 ]]; then
		log "invalid call to exportenv: must have 2 arguments but got $#, $*"
	fi
	printf '%s=%q\n' "${NAME}" "${VALUE}" >>/etc/environment
}

if [[ ${IN_DEBUG_MODE-} == yes ]]; then
	log "debug mode detected"
	systemctl enable console-getty.service
	cp /entrypoint/nofail.service /usr/local/lib/systemd/system/service.d/00-nofail.conf
	cp /entrypoint/nofail.service /usr/local/lib/systemd/system/socket.d/00-nofail.conf
	exportenv DEBUG_SHELL yes
	export IN_DEBUG_MODE
fi

if [[ -e ${NOTIFY_SOCKET-not exists} ]]; then
	export __NOTIFY_SOCKET__="${NOTIFY_SOCKET}"
	exportenv "__NOTIFY_SOCKET__" "${NOTIFY_SOCKET}"
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

env | grep -vE '^(SHLVL|PATH|_|container_uuid|HOME|PWD|TERM)=' >>/run/.userenvironments

CONTAINER_DIGIST_LONG=$(grep -F .containerenv /proc/self/mountinfo | grep -oE '[0-9a-f]{64}' || true)
CONTAINER_DIGIST_SHORT="$(echo "${CONTAINER_DIGIST_LONG}" | grep -oE '^[0-9a-f]{12}')"

exportenv 'CONTAINER_DIGIST_LONG' "${CONTAINER_DIGIST_LONG}"
exportenv 'CONTAINER_DIGIST_SHORT' "${CONTAINER_DIGIST_SHORT}"
exportenv 'CONTAINER_ID' "${CONTAINER_ID-}"

# this variable is set by `podman --systemd=always`, 32 digits
echo "${container_uuid-"debugger container $RANDOM"}" >/etc/machine-id
cat /etc/machine-id >/run/machine-id

if [[ $* == 'emergency' ]]; then
	log "emergency!"
	export DEBUG_SHELL=yes
	set -- bash --login -i
fi

log "prestart:"
while read -d '' -r FILE; do
	if [[ $FILE == *.md ]]; then
		continue
	fi
	log "    execute script: ${FILE}"
	source "${FILE}"
done < <(find /entrypoint/prestart.d -maxdepth 1 -type f -print0 | sort --zero-terminated)
log "prestart complete"

#####
declare -p CONTAINER_ID CONTAINER_DIGIST_SHORT container_uuid
#####

if [[ $* == '--systemd' || $# -eq 0 ]]; then
	log "executing systemd!"
	# capsh --print
	unset SHLVL PATH PWD
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
fi

if [[ $* == 'bash' ]]; then
	log "hello!"
	export DEBUG_SHELL=yes
	set -- bash --login -i
fi

exec "$@"
