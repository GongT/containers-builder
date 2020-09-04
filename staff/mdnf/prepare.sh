#!/usr/bin/env bash

set -Eeuo pipefail

rm -rf /var/lib/dnf/repos /var/cache/dnf
mkdir -p /var/lib/dnf/repos /var/cache/dnf
