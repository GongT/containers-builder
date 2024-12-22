#!/usr/bin/env bash

systemctl set-default "${DEFAULT_TARGET-multi-user.target}"

if [[ -e /etc/fedora-release ]]; then
	rm -rvf /usr/lib/systemd/system/local-fs.target.wants /usr/lib/systemd/system/graphical.target.wants /usr/lib/systemd/system/multi-user.target.wants
	rm -rvf /etc/systemd/system/*.target.wants

	cd /usr/lib/systemd/system/sysinit.target.wants
	rm -vf ./*.mount ./*.path ./systemd-firstboot.service ./systemd-machine-id-commit.service ./systemd-sysusers.service ./systemd-tpm2-* ./systemd-update-*
fi

systemctl disable console-getty.service || true
systemctl mask systemd-networkd-wait-online.service systemd-hostnamed.service kbrequest.target
systemctl enable dbus.socket notify-stop.service success.service || true

if [[ ! -e /etc/localtime ]]; then
	rm -f /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi

echo 'LANG=zh_CN.UTF-8
LC_TIME=en_DK.UTF-8
LC_MEASUREMENT=metric
' >/etc/locale.conf

rm -f /etc/machine-id
