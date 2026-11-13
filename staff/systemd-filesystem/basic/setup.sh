#!/usr/bin/env bash

declare -fp ensure_user ensure_group get_gid_of_group get_uid_of_user user_exists group_exists >/entrypoint/library/users.sh

info_note "设置默认目标为 ${DEFAULT_TARGET-multi-user.target}"
systemctl set-default "${DEFAULT_TARGET-multi-user.target}"

if [[ -e /etc/fedora-release ]]; then
	# 清理一些不需要的文件，目前只测试了fedora系统
	# 这些完整系统需要的东西在容器里不需要，甚至有可能导致容器启动失败
	rm -rvf /usr/lib/systemd/system/local-fs.target.wants /usr/lib/systemd/system/graphical.target.wants /usr/lib/systemd/system/multi-user.target.wants
	rm -rvf /etc/systemd/system/*.target.wants

	cd /usr/lib/systemd/system/sysinit.target.wants
	rm -vf ./*.mount \
		./*.path \
		./systemd-firstboot.service \
		./systemd-machine-id-commit.service \
		./systemd-sysusers.service \
		./systemd-tpm2-* \
		./systemd-update-*
fi

systemctl disable console-getty.service || true
systemctl mask systemd-networkd-wait-online.service systemd-hostnamed.service systemd-hostnamed.socket kbrequest.target
systemctl enable dbus.socket notify-stop.service success.service || true

if [[ ! -e /etc/localtime ]]; then
	rm -f /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi

# 可能存在这个文件，其内容会被启动时覆盖，避免混淆直接删除它
rm -f /etc/machine-id
