function use_apt_cache() {
	local -r SYSTEM="$1"
	info_log "using ${SYSTEM} apt cache: ${SYSTEM_COMMON_CACHE}/apt/${SYSTEM}/packages"
	mkdir -p "${SYSTEM_COMMON_CACHE}/apt/${SYSTEM}/packages" "${SYSTEM_COMMON_CACHE}/apt/${SYSTEM}/lists"
	rm -f "${SYSTEM_COMMON_CACHE}/apt/${SYSTEM}/lists/lock"
	echo "--volume=${SYSTEM_COMMON_CACHE}/apt/${SYSTEM}/packages:/var/cache/apt"
	echo "--volume=${SYSTEM_COMMON_CACHE}/apt/${SYSTEM}/lists:/var/lib/apt"
}

function use_debian_apt_cache() {
	use_apt_cache debian
}

function apt_get_install() {
	local BASE_TYPE=$1
	shift
	local NAME=$1
	shift

	control_ci group "apt-get install packages"

	{
		cat <<-'APT'
			die() {
				echo "$*">&2
				exit 1
			}
			rm -f /etc/apt/apt.conf.d/docker-clean
			echo "HTTP_PROXY=$HTTP_PROXY HTTPS_PROXY=$HTTPS_PROXY ALL_PROXY=$ALL_PROXY http_proxy=$http_proxy https_proxy=$https_proxy all_proxy=$all_proxy"
			I=0
			while true ; do
				if apt install "$@" ; then
					break
				fi
				apt update || true

				if [ "$I" -ge 10 ]; then
					die "can not install packages by apt-get."
				fi

				I=$(($I + 1))
				echo "failed... retry: $I"
			done
		APT
		if ! is_tty 0; then
			echo "### post scripts:"
			cat
		fi
	} | buildah run $(_use_apt_cache "${BASE_TYPE}") "${NAME}" sh -s- -- "$@"
	control_ci groupEnd
}

function make_base_image_by_apt() {
	local BASEIMG=$1
	shift
	local NAME=$1
	shift
	local PKGS=("$@")

	info "make base image by apt-get, from ${BASEIMG}"

	local POSTSCRIPT=""
	if ! is_tty 0; then
		POSTSCRIPT=$(cat)
	fi

	_apt_hash_cb() {
		xpodman image pull "${BASEIMG}"
		echo "${PKGS[*]} ${POSTSCRIPT}"
	}
	_apt_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "${BASEIMG}")
		echo "${POSTSCRIPT}" | apt_get_install "${BASEIMG}" "${CONTAINER}" "${PKGS[@]}"
	}

	if [[ ${FORCE_APT+found} != found ]]; then
		local FORCE_APT=""
	fi

	BUILDAH_FORCE="${FORCE_APT}" buildah_cache "${NAME}" _apt_hash_cb _apt_build_cb

	unset -f _apt_hash_cb _apt_build_cb
}
