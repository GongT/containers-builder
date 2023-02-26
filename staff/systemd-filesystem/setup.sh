#!/usr/bin/env bash

set -Eeuo pipefail

systemctl mask systemd-networkd-wait-online.service
systemctl disable rpmdb-migrate.service rpmdb-rebuild.service dnf-makecache.timer systemd-logind.service systemd-oomd.service systemd-oomd.socket systemd-networkd.socket || true
systemctl set-default multi-user.target
