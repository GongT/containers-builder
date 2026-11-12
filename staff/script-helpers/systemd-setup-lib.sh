# 写入变量到 /etc/environment 文件
# 此函数用于构建时期（setup_systemd步骤）的容器内脚本
function exportenv() {
	local -r NAME=$1 VALUE=$2 FORCE=${3-false}
	if [[ $# -ne 2 ]]; then
		die "启动脚本调用exportenv函数: 必须有2个参数，但得到 $# 个: $*"
	fi
	if grep -F "${NAME}=" /etc/environment; then
		die "重复的环境变量: ${NAME}"
	fi
	printf '%s=%q\n' "${NAME}" "${VALUE}" >>/etc/environment
}
