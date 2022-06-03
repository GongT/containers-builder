#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "./common_service_library.sh"

function query() {
	jq --exit-status --compact-output --monochrome-output --raw-output "$@"
}

function JQ() {
	echo "$JSON" | query "$@"
}

SERVER_LIST=()
while IFS= read -r LINE; do
	if ! [[ "$LINE" ]]; then
		continue
	fi
	SERVER_LIST+=("$LINE")
done < <(resolvectl dns | sed -E 's/^[^:]+://g' | xargs -n1 | grep -v --fixed-strings '127.0.0.1')

if [[ ${#SERVER_LIST[@]} -eq 0 ]]; then
	SERVER_LIST=(119.29.29.29 114.114.114.114)
fi
echo "SERVER_LIST=${SERVER_LIST[*]}"

TO_RESOLVE=()
JSON=$(podman info -f json | query '.registries')
for URL in $(JQ '.search[]'); do
	if JQ ".[\"$URL\"]" &>/dev/null; then
		TO_RESOLVE+=("$(JQ ".[\"$URL\"].Location")")
		for U in $(JQ ".[\"$URL\"].Mirrors[].Location"); do
			TO_RESOLVE+=("$U")
		done
	else
		TO_RESOLVE+=("$URL")
	fi
done

declare -A DOMAINS=()
for TARGET in "${TO_RESOLVE[@]}"; do
	HOST_PART=${TARGET%%:*}
	DOMAINS["$HOST_PART"]=1
done

for TARGET in "${!DOMAINS[@]}"; do
	for SERVER in "${SERVER_LIST[@]}"; do
		echo "server=/$TARGET/$SERVER"
	done
done | tee /etc/dnsmasq.d/99-create-dnsmasq-config.conf

dnsmasq -C /etc/dnsmasq.conf --test
