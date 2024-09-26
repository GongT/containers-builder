#!/usr/bin/env bash

systemctl unmask systemd-networkd-wait-online.service
if [[ ${ONLINE-yes} == yes ]]; then
	systemctl enable systemd-networkd-wait-online.service
else
	systemctl disable systemd-networkd-wait-online.service
fi
