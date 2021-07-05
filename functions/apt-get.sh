function _use_apt_cache() {
	local -r SYSTEM="$1"
	info_note "using $SYSTEM apt cache: $SYSTEM_COMMON_CACHE/${SYSTEM}_apt"
	mkdir -p "$SYSTEM_COMMON_CACHE/${SYSTEM}_apt" "$SYSTEM_COMMON_CACHE/${SYSTEM}_apt_lists"
	rm -f "$SYSTEM_COMMON_CACHE/${SYSTEM}_apt_lists/lock"
	echo "--volume=$SYSTEM_COMMON_CACHE/${SYSTEM}_apt:/var/cache/apt"
	echo "--volume=$SYSTEM_COMMON_CACHE/${SYSTEM}_apt_lists:/var/lib/apt/lists"
}

function use_debian_apt_cache() {
	_use_apt_cache debian
}
