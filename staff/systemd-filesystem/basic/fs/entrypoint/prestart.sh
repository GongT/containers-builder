if ! declare -fp log &>/dev/null; then
	# shellcheck source=./library/all-load.sh
	source "/entrypoint/library/all-load.sh"
	log "独立运行模式，仅用于调试"
fi

log "启动前hook:"
declare -a HOOK_FILES=()
list_scripts_in_dir HOOK_FILES /entrypoint/prestart.d
log "  * 共有 ${#HOOK_FILES[@]} 个prestart脚本"
declare -i INDEX=1
for FILE in "${HOOK_FILES[@]}"; do
	log "[${INDEX}] 导入执行hook脚本: ${FILE}"
	# shellcheck source=/dev/null
	source "${FILE}"
	INDEX+=1
done
log "启动前hook运行完成"
