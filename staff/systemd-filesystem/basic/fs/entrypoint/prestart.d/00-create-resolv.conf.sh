log "before modify /etc/resolv.conf, it is:"
cat /etc/resolv.conf >&2
log "====="

{
	# TODO: split this another place
	if [[ "${RESOLVE_OPTIONS-}" ]]; then
		log "RESOLVE_OPTIONS=${RESOLVE_OPTIONS}"
		echo "options $RESOLVE_OPTIONS"
	fi
	if [[ "${RESOLVE_SEARCH-}" ]]; then
		log "RESOLVE_SEARCH=${RESOLVE_SEARCH}"
		echo "search $RESOLVE_SEARCH"
	fi
	if [[ "${NSS-}" ]]; then
		log "NSS=${NSS}"
		mapfile -d ' ' -t NSS < <(echo "$NSS")
		for NS in "${NSS[@]}"; do
			echo "nameserver $NS"
		done
	else
		log "NSS is empty, use 8.8.8.8"
		echo "nameserver 8.8.8.8"
	fi
} >/etc/resolv.conf
