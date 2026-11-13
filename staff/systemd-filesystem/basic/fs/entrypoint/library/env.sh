# 写入变量到 /etc/environment 文件
# 由于通过systemd全局override机制设置了 EnvironmentFile=/etc/environment
# 这样写入的变量会被所有service自动加载
function exportenv() {
	local -r NAME=${1} VALUE=${2}
	if [[ $# -gt 2 ]]; then
		die "启动脚本调用exportenv函数: 必须有2个参数，但得到 $# 个: $*"
	fi
	printf '%s=%q\n' "${NAME}" "${VALUE}" >>/etc/environment
}
