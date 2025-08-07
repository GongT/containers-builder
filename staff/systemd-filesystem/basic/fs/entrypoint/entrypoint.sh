#!/bin/bash

log "arguments: $# - $*"

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS

# shellcheck source=./library/log.sh
source "/entrypoint/library/log.sh"
# shellcheck source=./library/env.sh
source "/entrypoint/library/env.sh"

if [[ $* == 'emergency' ]]; then
	log "emergency!"
	export DEBUG_SHELL=yes
	set -- bash --login -i
fi

log "prestart:"
while read -d '' -r FILE; do
	if [[ $FILE == *.md ]]; then
		continue
	fi
	log "    execute script: ${FILE}"
	# shellcheck source=/dev/null
	source "${FILE}"
done < <(find /entrypoint/prestart.d -maxdepth 1 -type f -print0 | sort --zero-terminated)
log "prestart complete"

if [[ $* == '--systemd' || $# -eq 0 ]]; then
	log "executing systemd!"
	# capsh --print
	unset SHLVL PATH PWD
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
fi

if [[ $* == 'bash' || $* == 'sh' || $* == 'shell' ]]; then
	log "hello!"
	export DEBUG_SHELL=yes
	set -- bash --login -i
fi

exec "$@"
