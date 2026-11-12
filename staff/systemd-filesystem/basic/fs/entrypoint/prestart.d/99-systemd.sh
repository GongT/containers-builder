# 准备一些 systemd 相关的配置

if [[ ${IN_DEBUG_MODE-} == yes ]]; then
	log "检测到调试模式，启用调试控制台并禁止服务失败后退出容器"
	systemctl enable console-getty.service
	cp /entrypoint/nofail.service /usr/local/lib/systemd/system/service.d/00-nofail.conf
	cp /entrypoint/nofail.service /usr/local/lib/systemd/system/socket.d/00-nofail.conf
	log "  -> DEBUG_SHELL=yes"
	exportenv DEBUG_SHELL yes
	export IN_DEBUG_MODE
fi

# NOTIFY_SOCKET已设置且存在
if [[ -e ${NOTIFY_SOCKET-not exists} ]]; then
	systemd-notify "--status=system boot up"
	systemd-notify "EXTEND_TIMEOUT_USEC=30000000"
	log "NOTIFY_SOCKET=${NOTIFY_SOCKET}"

	# 调试用
	echo "export NOTIFY_SOCKET=${NOTIFY_SOCKET}" >>/root/.bashrc

	if ! systemctl is-enabled success.service --quiet; then
		# 如果 success.service 没有启用（通常情况），则启用它
		# 默认应被安装到default.target的requires中
		systemctl enable success.service
	fi

	export __NOTIFY_SOCKET__="${NOTIFY_SOCKET}"
else
	log "NOTIFY_SOCKET(${NOTIFY_SOCKET-'*missing*'}) 不存在，禁用相关服务"
	systemctl disable success.service notify-stop.service
	systemctl mask success.service notify-stop.service
	rm -f /usr/local/lib/systemd/system/multi-user.target.d/require-success.conf
fi
unset NOTIFY_SOCKET

env | grep -vE '^(SHLVL|PATH|_|container_uuid|HOME|PWD|TERM)=' >>/run/.userenvironments
