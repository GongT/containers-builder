#!/bin/bash

# shellcheck source=./library/log.sh
source "/entrypoint/library/log.sh"
log "arguments: $# - $*"
# shellcheck source=./library/env.sh
source "/entrypoint/library/env.sh"

if [[ $* == 'emergency' ]]; then
	log "emergency!"
	export DEBUG_SHELL=yes
	exec /usr/bin/bash --login -i
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

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS

if [[ $* == '--systemd' || $# -eq 0 ]]; then
	log "executing systemd!"
	# capsh --print
	unset SHLVL PATH PWD
	exec /usr/lib/systemd/systemd --system "--show-status=yes" --crash-reboot=no
fi

if [[ $* == 'bash' || $* == 'sh' || $* == 'shell' ]]; then
	log "hello!"
	export DEBUG_SHELL=yes
	set -- /usr/bin/bash --login -i
fi

exec "$@"
