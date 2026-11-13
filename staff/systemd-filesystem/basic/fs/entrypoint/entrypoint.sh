#!/usr/bin/bash

echo "[entry] 容器内进程开始运行，${#} 个参数: $*" >&2

if [[ $* == '--systemd' || $# -eq 0 ]]; then
	_MODE=systemd
elif [[ $* == 'bash' || $* == 'sh' || $* == 'shell' ]]; then
	_MODE=shell
elif [[ $* == 'emergency' ]]; then
	_MODE=emergency
	echo "发现参数 emergency 跳过hook并进入shell" >&2
	touch /run/.userenvironments /etc/environment
	exec /usr/bin/bash --login -i
else
	# log "单独执行命令: $*"
	exec "$@"
fi

# shellcheck source=./library/all-load.sh
source "/entrypoint/library/all-load.sh"

# shellcheck source=./prestart.sh
source "/entrypoint/prestart.sh"

if [[ $_MODE == systemd ]]; then
	log "运行 systemd"
	# capsh --print
	unset SHLVL PATH PWD
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
elif [[ $_MODE == shell ]]; then
	log "发现shell参数，进入调试"
	echo "" >&2
	exec /usr/bin/bash --login -i
else
	die "未知的运行模式: $_MODE"
fi
