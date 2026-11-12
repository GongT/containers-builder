function use_alpine_apk_cache() {
	info_log "使用apk缓存: ${SYSTEM_COMMON_CACHE}/apk"
	mkdir -p "${SYSTEM_COMMON_CACHE}/apk"
	echo -e "--volume=${SYSTEM_COMMON_CACHE}/apk:/etc/apk/cache"
}

function apk_install() {
	local NAME=$1
	shift

	control_ci group "apk 安装软件包"

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
					die "无法通过apk安装软件包."
				fi

				I=$(($I + 1))
				echo "安装失败... 重试: $I"
			done
		APK
		if ! is_tty 0; then
			echo "### apk后处理脚本:"
			cat
		fi
	} | buildah run $(use_alpine_apk_cache) "${NAME}" sh -s- -- "$@"
	control_ci groupEnd
}

function make_base_image_by_apk() {
	local BASEIMG=$1 NAME=$2
	shift
	shift
	local PKGS=("$@")

	info "利用alpine apk制作基础镜像, 来自 ${BASEIMG}"

	local POSTSCRIPT=""
	if ! is_tty 0; then
		POSTSCRIPT=$(cat)
	fi

	_apk_hash_cb() {
		xpodman image pull "${BASEIMG}"
		echo "${PKGS[*]} ${POSTSCRIPT}"
	}
	_apk_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "${BASEIMG}")
		echo "${POSTSCRIPT}" | apk_install "${CONTAINER}" "${PKGS[@]}"
	}

	if [[ ${FORCE_APK+found} != found ]]; then
		local FORCE_APK=""
	fi

	BUILDAH_FORCE="${FORCE_APK}" buildah_cache "${NAME}" _apk_hash_cb _apk_build_cb

	unset -f _apk_hash_cb _apk_build_cb
}
