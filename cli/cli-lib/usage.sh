#!/usr/bin/env bash

function l() {
	local N=$1
	shift
	echo -e "    \e[38;5;14m$N\e[0m: $*"
}

function usage() {
	local Z=$0
	echo "用法: $Z action"
	echo
	echo "镜像管理:"
	if [[ $Z == */bin.sh ]]; then
		l install "安装（链接）bin.sh 到 /usr/local/bin/ms，并安装自动拉镜像的脚本"
	fi
	l upgrade "重新执行所有已安装服务的安装脚本"

	echo
	echo "服务控制:"
	l status "显示所有服务状态"
	l ls "（用于脚本）列出服务名称"
	for I in start restart stop reload reset-failed; do
		l "$I" "对每个服务使用${I}命令"
	done
	l log "显示单个服务本次运行的日志（-f：跟踪模式）"
	l logs "显示全部服务日志（-f：跟踪模式）"
	l abort "如果某个服务正在启动，则中止他的启动过程"
	l refresh "检查哪些容器的镜像已经更新（--run：自动运行重启命令）"

	echo
	echo "其他工具:"
	l attach "在镜像里运行命令（默认运行sh）"
	l nsenter "运行nsenter命令"
	l pstree "显示容器进程树"
	l rm "停止服务，并删除服务文件"
	l pull "拉取新镜像版本（--force：无视最近记录）"
	echo
}
