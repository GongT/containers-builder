function use_pacman_cache() {
	local -r SYSTEM="${1:-archlinux}"
	info_note "using $SYSTEM pacman cache: $SYSTEM_COMMON_CACHE/pacman/${SYSTEM}/packages"
	mkdir -p "$SYSTEM_COMMON_CACHE/pacman/${SYSTEM}/packages" "$SYSTEM_COMMON_CACHE/pacman/${SYSTEM}/lists"
	echo "--volume=$SYSTEM_COMMON_CACHE/pacman/${SYSTEM}/packages:/var/cache/pacman"
	echo "--volume=$SYSTEM_COMMON_CACHE/pacman/${SYSTEM}/lists:/var/lib/pacman/sync"
}
