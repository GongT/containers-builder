# 根据外部控制器传入的几个环境变量生成 /etc/resolv.conf 文件
# 即使外部没有传入（裸调试状态）也强制覆写

if [[ -e /etc/resolv.conf ]]; then
	log "即将覆盖 /etc/resolv.conf 文件, 原始内容为:"
	cat /etc/resolv.conf >&2
	mv /etc/resolv.conf /etc/resolv.conf.old || true
	unlink /etc/resolv.conf.old || true
else
	log "即将创建新的 /etc/resolv.conf 文件"
fi

{
	# TODO: split this another place
	if [[ -n "${RESOLVE_OPTIONS-}" ]]; then
		log "  -> RESOLVE_OPTIONS=${RESOLVE_OPTIONS}"
		echo "options $RESOLVE_OPTIONS"
	fi
	if [[ -n "${RESOLVE_SEARCH-}" ]]; then
		log "  -> RESOLVE_SEARCH=${RESOLVE_SEARCH}"
		echo "search $RESOLVE_SEARCH"
	fi
	if [[ -n "${NSS-}" ]]; then
		log "  -> NSS=${NSS}"
		mapfile -d ' ' -t NSS < <(echo "$NSS")
		for NS in "${NSS[@]}"; do
			echo "nameserver ${NS}"
		done
	else
		log "NSS 环境变量是空的，DNS使用 8.8.8.8"
		echo "nameserver 8.8.8.8"
	fi
} >/etc/resolv.conf

log "已生成 /etc/resolv.conf 文件"
cat /etc/resolv.conf >&2
log "====="

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS
