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
	systemd-notify "--status=system boot up"
	systemd-notify "EXTEND_TIMEOUT_USEC=30000000"
	echo "export NOTIFY_SOCKET=${NOTIFY_SOCKET}" >>/root/.bashrc
	log "NOTIFY_SOCKET=${NOTIFY_SOCKET}"
else
	log "NOTIFY_SOCKET is not exists, disable success notify service."
	systemctl disable success.service notify-stop.service
	systemctl mask success.service notify-stop.service
	rm -f /usr/local/lib/systemd/system/multi-user.target.d/require-success.conf
fi
unset NOTIFY_SOCKET

env | grep -vE '^(SHLVL|PATH|_|container_uuid|HOME|PWD|TERM)=' >>/run/.userenvironments
