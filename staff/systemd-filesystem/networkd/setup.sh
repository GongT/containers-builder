#!/usr/bin/env bash

systemctl unmask systemd-resolved.service systemd-networkd.service systemd-networkd-wait-online.service
systemctl enable systemd-resolved.service systemd-networkd.service

if [[ ${ONLINE-yes} == yes ]]; then
	systemctl enable systemd-networkd-wait-online.service
else
	systemctl disable systemd-networkd-wait-online.service
fi

# 配置 systemd-resolved 依赖于 systemd-networkd
mkdir -p /usr/lib/systemd/system/systemd-resolved.service.d
echo "[Unit]
Requires=systemd-networkd.service
After=systemd-networkd.service
" >/usr/lib/systemd/system/systemd-resolved.service.d/00-requires-networkd.conf
