#!/usr/bin/env bash

systemctl unmask systemd-resolved.service systemd-networkd.service systemd-networkd-wait-online.service
systemctl enable systemd-resolved.service systemd-networkd.service

if [[ ${ONLINE-yes} == yes ]]; then
	systemctl enable systemd-networkd-wait-online.service
else
	systemctl disable systemd-networkd-wait-online.service
fi
