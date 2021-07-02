function use_alpine_apk_cache() {
	info_note "using apk cache: $SYSTEM_COMMON_CACHE/apk"
	mkdir -p "$SYSTEM_COMMON_CACHE/apk"
	echo -e "--volume=$SYSTEM_COMMON_CACHE/apk:/etc/apk/cache"
}

function apk_install() {
	local NAME=$1
	shift

	control_ci group "apk install packages"

	{
		cat <<-'APK'
			die() {
				echo "$*">&2
				exit 1
			}
			echo "HTTP_PROXY=$HTTP_PROXY HTTPS_PROXY=$HTTPS_PROXY ALL_PROXY=$ALL_PROXY http_proxy=$http_proxy https_proxy=$https_proxy all_proxy=$all_proxy"
			I=0
			while true ; do
				if apk add "$@" ; then
					break
				fi
				apk update || true

				if [ "$I" -ge 10 ]; then
					die "can not install packages by apk."
				fi

				I=$(($I + 1))
				echo "failed... retry: $I"
			done
		APK
		if [[ ! -t 0 ]]; then
			echo "### post scripts:"
			cat
		fi
	} | buildah run $(use_alpine_apk_cache) "$NAME" sh -s- -- "$@"
	control_ci groupEnd
}

function make_base_image_by_apk() {
	local BASEIMG=$1 NAME=$2
	shift
	shift
	local PKGS=("$@")

	info "make base image by alpine apk, from $BASEIMG"

	local POSTSCRIPT=""
	if [[ ! -t 0 ]]; then
		POSTSCRIPT=$(cat)
	fi

	_apk_hash_cb() {
		image_get_id "$BASEIMG"
		echo "${PKGS[*]} $POSTSCRIPT" | md5sum
	}
	_apk_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "$BASEIMG")
		echo "$POSTSCRIPT" | apk_install "$CONTAINER" "${PKGS[@]}"
	}

	if [[ ${FORCE_APK+found} != found ]]; then
		local FORCE_APK=""
	fi

	BUILDAH_FORCE="$FORCE_APK" buildah_cache "$NAME" _apk_hash_cb _apk_build_cb

	unset -f _apk_hash_cb _apk_build_cb
}
