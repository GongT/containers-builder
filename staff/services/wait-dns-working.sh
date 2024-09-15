#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "./common_service_library.sh"

function query() {
	jq --exit-status --compact-output --monochrome-output --raw-output "$@"
}

function JQ() {
	echo "${JSON}" | query "$@"
}

function try() {
	if [[ -z ${NOTIFY_SOCKET:-} ]]; then
		echo -ne "\e[2m"
	fi
	while true; do
		expand_timeout 32
		if nslookup -timeout=30 "$1" "${2:-}" | grep -i -A 100 "$1" &>/dev/null; then
			echo "  - success"
			break
		fi
		echo "  - failed"
		sleep 1
	done
	if [[ -z ${NOTIFY_SOCKET:-} ]]; then
		echo -ne "\e[0m"
	fi
}

TO_RESOLVE=()
JSON=$(podman info -f json | query '.registries')
for URL in $(JQ '.search[]'); do
	if JQ ".[\"${URL}\"]" &>/dev/null; then
		mapfile -t MIRRORS_URL < <(JQ ".[\"${URL}\"].Mirrors[].Location")
		if [[ ${#MIRRORS_URL[@]} -gt 0 ]]; then
			for U in "${MIRRORS_URL[@]}"; do
				TO_RESOLVE+=("${U}")
			done
		else
			TO_RESOLVE+=("$(JQ ".[\"${URL}\"].Location")")
		fi
	else
		TO_RESOLVE+=("${URL}")
	fi
done

declare -A DOMAINS=()
for TARGET in "${TO_RESOLVE[@]}"; do
	if [[ -z ${TARGET} ]]; then
		continue
	fi
	HOST_PART=${TARGET%%:*}
	DOMAINS["${HOST_PART}"]=1
done

for TARGET in "${!DOMAINS[@]}"; do
	sdnotify "try resolve ${TARGET}"
	try "${TARGET}"
done
startup_done
