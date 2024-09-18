#!/usr/bin/env bash

source "../../package/include.sh"
use_normal

function JQ() {
	# use parse_json
	local -r FILTER="\$ARGS.named.JSON${1}"
	filtered_jq --null-input "${FILTER}" --argjson JSON "${JSON}"
}

function try_resolve() {
	while true; do
		expand_timeout_seconds 32
		if nslookup -timeout=30 "$1" | grep -i -A 100 "$1" &>/dev/null; then
			info_log "  - success"
			break
		fi
		info_log "  - failed"
		sleep 1
	done
}

TO_RESOLVE=()
JSON=$(podman info -f json | filtered_jq '.registries')
readonly JSON
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
	info "try resolve ${TARGET}"
	try_resolve "${TARGET}"
done
