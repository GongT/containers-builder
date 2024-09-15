#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-dnf"
source ../../functions-build.sh
guard_no_root

CID=$(new_container test scratch)
collect_temp_container "${CID}"

# rpmfusion-nonfree "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

dnf_use_environment --rpmdb=remove --enable=rpmfusion-free-debuginfo \
	--repo="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"

call_dnf_install "${CID}" pkgs/bash.lst
