function use_alpine_apk_cache() {
	info_note "using apk cache: $SYSTEM_COMMON_CACHE/apk"
	echo -e "--volume=$SYSTEM_COMMON_CACHE/apk:/etc/apk/cache"
}
