if [[ ${IN_DEBUG_MODE-} == yes ]]; then
	log "检测到调试模式，启用调试控制台并禁止服务失败后退出容器"
	systemctl enable console-getty.service
	for TYPE in service socket default.target; do
		mkdir -p "/usr/local/lib/systemd/system/${TYPE}.d"
		echo "[Unit]
FailureAction=none
" >"/usr/local/lib/systemd/system/${TYPE}.d/99-nofail.conf"
	done
	unset TYPE
	exportenv IN_DEBUG_MODE yes
	systemctl disable notify-stop.service
	rm -f /usr/local/lib/systemd/system/multi-user.target.d/require-success.conf
elif [[ -z ${NOTIFY_SOCKET-} ]]; then
	log "非调试模式下 NOTIFY_SOCKET 不存在！！！"
	exit 233
fi
