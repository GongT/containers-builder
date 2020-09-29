function use_alpine_apk_cache() {
	info_note "using apk cache: $SYSTEM_COMMON_CACHE/apk"
	mkdir -p "$SYSTEM_COMMON_CACHE/apk"
	echo -e "--volume=$SYSTEM_COMMON_CACHE/apk:/etc/apk/cache"
}

function run_apt() {
	local NAME=$1
	shift

	buildah run $(use_alpine_apk_cache) "$CONTAINER" sh -s- -- "${PKGS[@]}" <<- 'APK'
		echo "APK: install $*"
		echo "HTTP_PROXY=$HTTP_PROXY HTTPS_PROXY=$HTTPS_PROXY ALL_PROXY=$ALL_PROXY http_proxy=$http_proxy https_proxy=$https_proxy all_proxy=$all_proxy"
		I=0
		while [ "$I" -lt 3 ] ; do
			if apk add "$@" ; then
				exit 0
			fi
			apk update || true

			I=$(($I + 1))
			echo "failed... retry: $I"
		done
		echo "can not install package."
		exit 1
	APK
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
		run_apt "$CONTAINER" "${PKGS[@]}"
	}

	if [[ "${FORCE_APK+found}" != found ]]; then
		local FORCE_APK=""
	fi

	BUILDAH_FORCE="$FORCE_APK" buildah_cache "$NAME" _apk_hash_cb _apk_build_cb

	unset -f _apk_hash_cb _apk_build_cb
}
