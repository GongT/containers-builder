#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s nullglob

rm -f /etc/machine-id
rm -rf /usr/lib/systemd/system/local-fs.target.wants /usr/lib/systemd/system/graphical.target.wants /usr/lib/systemd/system/multi-user.target.wants
rm -rf /etc/systemd/system/*.target.wants

cd /usr/lib/systemd/system/sysinit.target.wants
rm -f ./*.mount ./*.path ./systemd-firstboot.service ./systemd-machine-id-commit.service ./systemd-sysusers.service ./systemd-tpm2-* ./systemd-update-*

systemctl enable console-getty || true
systemctl mask systemd-networkd-wait-online.service

systemctl enable success.service
systemctl set-default multi-user.target 

if [[ ! -e /etc/localtime ]]; then
	rm -f /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi
