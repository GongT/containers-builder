function use_alpine_apk_cache() {
	info_note "using apk cache: $SYSTEM_COMMON_CACHE/apk"
	mkdir -p "$SYSTEM_COMMON_CACHE/apk/pkgs" "$SYSTEM_COMMON_CACHE/apk/list"
	echo -e "--volume=$SYSTEM_COMMON_CACHE/apk:/etc/apk/cache"
}
