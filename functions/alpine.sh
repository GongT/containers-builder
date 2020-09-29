function use_alpine_apk_cache() {
	info_note "using apk cache: $SYSTEM_COMMON_CACHE/apk"
	mkdir -p "$SYSTEM_COMMON_CACHE/apk"
	echo -e "--volume=$SYSTEM_COMMON_CACHE/apk:/etc/apk/cache"
}

function make_base_image_by_apt() {
	local BASEIMG=$1 NAME=$2
	shift
	shift
	local PKGS=("$@")

	_apk_hash_cb() {
		echo "${PKGS[*]}" | md5sum
	}
	_apk_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "$BASEIMG")
		buildah run $(use_alpine_apk_cache) "$CONTAINER" apk add -U "${PKGS[@]}"
	}

	if [[ "${FORCE_APK+found}" != found ]]; then
		local FORCE_APK=""
	fi

	BUILDAH_FORCE="$FORCE_APK" buildah_cache "$NAME" _apk_hash_cb _apk_build_cb

	unset -f _apk_hash_cb _apk_build_cb
}
