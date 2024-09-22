{
	# TODO: split this another place
	if [[ "${RESOLVE_OPTIONS-}" ]]; then
		echo "options $RESOLVE_OPTIONS"
	fi
	if [[ "${RESOLVE_SEARCH-}" ]]; then
		echo "search $RESOLVE_SEARCH"
	fi
	if [[ "${NSS-}" ]]; then
		mapfile -d ' ' -t NSS < <(echo "$NSS")
		for NS in "${NSS[@]}"; do
			echo "nameserver $NS"
		done
	else
		echo "nameserver 8.8.8.8"
	fi
} >/etc/resolv.conf
