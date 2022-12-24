#!/usr/bin/env bash

env

set -xEeuo pipefail

dnf makecache

dnf install -y yum-utils \
	https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-37.noarch.rpm \
	https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-37.noarch.rpm

dnf config-manager --set-enabled rpmfusion-free rpmfusion-nonfree
