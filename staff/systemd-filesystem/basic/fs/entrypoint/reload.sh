#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./library/log.sh
source "/entrypoint/library/log.sh"

log "执行默认重载..."

declare -i RET=0
mapfile -d '' FILES < <(find /entrypoint/reload.d -maxdepth 1 -type f -print0 | sort --zero-terminated)

for FILE in "${FILES[@]}"; do
	if [[ ${FILE} == *.md ]]; then
		continue
	fi

	BASE=$(basename "${FILE}")
	if [[ -s ${FILE} ]]; then
		log "执行Bash脚本: ${BASE}"
		if bash "${FILE}"; then
			log "  - ok"
		else
			log "  - failed"
			RET=$?
		fi
	else
		log "重载systemd服务: ${FILE}"
		if systemctl reload "${BASE}"; then
			log "  - ok"
		else
			log "  - failed"
			RET=$?
		fi
	fi
done
log "重载完成，返回码: ${RET}"

exit "${RET}"
