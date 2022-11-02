#!/usr/bin/env bash

env

set -xEeuo pipefail

dnf makecache

dnf install -y yum-utils \
	https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-36.noarch.rpm \
	https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-36.noarch.rpm

dnf config-manager --set-enabled rpmfusion-free rpmfusion-nonfree
