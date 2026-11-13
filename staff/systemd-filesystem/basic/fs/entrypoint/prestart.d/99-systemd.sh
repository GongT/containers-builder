# 准备一些 systemd 相关的配置

if [[ -e ${NOTIFY_SOCKET-not exists} ]]; then
	log "NOTIFY_SOCKET=${NOTIFY_SOCKET}"

	# 调试用
	echo "export NOTIFY_SOCKET=${NOTIFY_SOCKET}" >>/root/.bashrc

	export __NOTIFY_SOCKET__="${NOTIFY_SOCKET}"
	exportenv "__NOTIFY_SOCKET__" "${NOTIFY_SOCKET}"
fi
unset NOTIFY_SOCKET

systemd-host-notify "--status=容器系统启动" "EXTEND_TIMEOUT_USEC=30000000"

env | grep -vE '^(SHLVL|PATH|_|container_uuid|HOME|PWD|TERM)=' >>/run/.userenvironments
