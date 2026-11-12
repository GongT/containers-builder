#!/usr/bin/bash

if [[ $* == '--systemd' || $# -eq 0 ]]; then
	_MODE=systemd
elif [[ $* == 'bash' || $* == 'sh' || $* == 'shell' ]]; then
	_MODE=shell
else
	# log "单独执行命令: $*"
	exec "$@"
fi

# shellcheck source=./library/all-load.sh
source "/entrypoint/library/all-load.sh"

log "容器内进程开始运行，参数: $# - $*"

if [[ $* == 'emergency' ]]; then
	touch /run/.userenvironments /etc/environment
	log "发现参数 emergency 跳过hook并进入shell"
	export DEBUG_SHELL=yes
	exec /usr/bin/bash --login -i
fi

log "启动前hook:"

declare -a HOOK_FILES=()
list_scripts_in_dir HOOK_FILES /entrypoint/prestart.d
log "  * 共有 ${#HOOK_FILES[@]} 个prestart脚本"
for FILE in "${HOOK_FILES[@]}"; do
	log "  - 导入执行hook脚本: ${FILE}"
	# shellcheck source=/dev/null
	source "${FILE}"
done
log "启动前hook运行完成"

if [[ $_MODE == systemd ]]; then
	log "运行 systemd"
	# capsh --print
	unset SHLVL PATH PWD
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
elif [[ $_MODE == shell ]]; then
	log "发现shell参数，进入调试"
	echo "" >&2
	export DEBUG_SHELL=yes
	set -- /usr/bin/bash --login -i
else
	die "未知的运行模式: $_MODE"
fi
