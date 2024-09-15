#!/usr/bin/env bash

# shellcheck source=package/include.sh
source /usr/lib/lib.sh

dnf install dnf-plugins-core jq util-linux-core curl

if [[ -e /opt/repos ]]; then
	find /opt/repos -name '*.repo' -print0 | xargs -0 --no-run-if-empty cp -vt /etc/yum.repos.d
	find /opt/repos -name '*.rpm' -print0 | xargs -0 --no-run-if-empty dnf install -y
fi

if [[ ${#DNF_ENVIRONMENT_ENABLES[@]} -gt 0 ]]; then
	dnf config-manager --set-enabled "${DNF_ENVIRONMENT_ENABLES[@]}"
fi
