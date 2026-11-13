#!/usr/bin/env bash

declare -fp ensure_user ensure_group get_gid_of_group get_uid_of_user user_exists group_exists >/entrypoint/library/users.sh

x() {
	echo "+ $*" >&2
	"$@"
}

info_note "设置默认目标为 ${DEFAULT_TARGET-multi-user.target}"
x systemctl set-default "${DEFAULT_TARGET-multi-user.target}"

clear_unused() {
	local R=$1

	# 清理一些不需要的文件，目前只测试了fedora系统
	# 这些完整系统需要的东西在容器里不需要，甚至有可能导致容器启动失败
	x rm -rf \
		"$R"/local-fs.target.wants \
		"$R"/graphical.target.wants \
		"$R"/multi-user.target.wants \
		"$R"/*.target.wants \
		\
		"$R"/sysinit.target.wants/*.mount \
		"$R"/sysinit.target.wants/*.path \
		"$R"/sysinit.target.wants/systemd-firstboot.service \
		"$R"/sysinit.target.wants/systemd-machine-id-commit.service \
		"$R"/sysinit.target.wants/systemd-tpm2-* \
		"$R"/sysinit.target.wants/systemd-update-* \
		\
		"$R"/sockets.target.wants/systemd-resolved-*.socket \
		"$R"/sockets.target.wants/systemd-storage-*.socket \
		"$R"/sockets.target.wants/systemd-report-*.socket \
		"$R"/sockets.target.wants/systemd-ask-password.socket \
		"$R"/sockets.target.wants/systemd-creds.socket \
		"$R"/sockets.target.wants/systemd-factory-reset.socket
}

if [[ -e /etc/fedora-release ]]; then
	clear_unused /etc/systemd/system
	clear_unused /usr/lib/systemd/system
fi

x systemctl mask systemd-networkd-wait-online.service systemd-hostnamed.service systemd-hostnamed.socket kbrequest.target
x systemctl enable notify-stop.service success.service

if [[ ! -e /etc/localtime ]]; then
	x rm -f /etc/localtime
	x ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi

# 可能存在这个文件，其内容会被启动时覆盖，避免混淆直接删除它
x rm -f /etc/machine-id
