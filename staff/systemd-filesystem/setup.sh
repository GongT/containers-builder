#!/usr/bin/env bash

set -Eeuo pipefail

systemctl disable rpmdb-migrate.service rpmdb-rebuild.service dnf-makecache.timer || true
systemctl set-default multi-user.target
