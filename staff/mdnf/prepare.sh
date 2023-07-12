#!/usr/bin/env bash

env

set -xEeuo pipefail

dnf makecache

dnf install -y dnf-plugins-core \
	"https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_VERSION.noarch.rpm" \
	"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_VERSION.noarch.rpm"

dnf config-manager --set-enabled rpmfusion-free rpmfusion-nonfree
