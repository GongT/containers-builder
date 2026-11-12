# 处理容器 ID 和容器名称，确保环境变量正确设置
# 其中容器ID和名称都是全局唯一的，通常只需要用名称（但变量名仍然是ID，这和docker的做法一致）
# 容器ID相对难以调试，实际和名称用起来一样
# 鉴于名称更加常用，所以将它写入了 /run/machine-id 文件

CONTAINER_DIGITS_LONG=$( grep -F .containerenv /proc/self/mountinfo | grep -oE '[0-9a-f]{64}') || true
log  "  -> ${CONTAINER_DIGITS_LONG}"
if [[ ${#CONTAINER_DIGITS_LONG} -ne 64 ]]; then
	die "容器 ID 长度不正确，应为 64，实为 ${#CONTAINER_DIGITS_LONG}: ${CONTAINER_DIGITS_LONG}"
fi

# 取前12位，类似docker的短ID
CONTAINER_DIGITS_SHORT="${CONTAINER_DIGITS_LONG:0:12}"
info " --> ${CONTAINER_DIGITS_SHORT}"

exportenv 'CONTAINER_DIGITS_LONG' "${CONTAINER_DIGITS_LONG}"
exportenv 'CONTAINER_DIGITS_SHORT' "${CONTAINER_DIGITS_SHORT}"

if [[ -n ${CONTAINER_ID-} ]]; then
	log "管理程序传入了容器名称"
else
	log "管理程序未传入容器名称，随机生成"
	CONTAINER_ID="debugger_container_${RANDOM}"
fi
exportenv 'CONTAINER_ID' "${CONTAINER_ID}"

# 写入/etc/machine-id，随后启动的systemd将使用该ID
echo "${CONTAINER_ID}" >/etc/machine-id
echo "${CONTAINER_ID}" >/run/machine-id
log "  -> ${CONTAINER_ID} | 已写入 /etc/machine-id"

# systemd支持使用此环境变量设置/etc/machine-id，不过我们自己做了，所以不需要它
unset container_uuid
