#!/usr/bin/env bash

REPO_CACHE_DIR="$SYSTEM_COMMON_CACHE/dnf/repos"

mkdir -p "$REPO_CACHE_DIR" "$SYSTEM_COMMON_CACHE/dnf/packges"

TMPREPODIR=

declare -ra DNF_RUN_ARGS=(
	"--volume=$REPO_CACHE_DIR:/var/lib/dnf/repos"
	"--volume=$SYSTEM_COMMON_CACHE/dnf/packges:/var/cache/dnf"
	"--env=FEDORA_VERSION=$FEDORA_VERSION"
	"--cap-add=CAP_SYS_ADMIN"
)

function _dnf_prep() {
	if container_exists mdnf; then
		DNF=$(container_get_id mdnf)
	else
		control_ci group "prepare dnf container"
		DNF=$(new_container "mdnf" "fedora:$FEDORA_VERSION")
		buildah copy "$DNF" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
		buildah copy --chmod=0777 "$DNF" "$COMMON_LIB_ROOT/staff/mdnf/bin.sh" /usr/bin/dnf.sh
		buildah run "${DNF_RUN_ARGS[@]}" "--volume=$COMMON_LIB_ROOT/staff/mdnf/prepare.sh:/tmp/_script" "$DNF" bash /tmp/_script
		control_ci groupEnd
	fi

	if [[ "${http_proxy-}" ]]; then
		info_warn "dnf is using proxy $http_proxy."
		buildah run "$DNF" sh -c "echo 'proxy=$http_proxy' >> /etc/dnf/dnf.conf"
	else
		buildah run "$DNF" sh -c "sed -i '/proxy=/d' /etc/dnf/dnf.conf"
	fi
}

function dnf_install() {
	local CACHE_NAME="$1"
	local PKG_LIST_FILE="$2"

	info_log "dnf install (list file: $PKG_LIST_FILE)..."

	_dnf_hash_cb() {
		cat "$PKG_LIST_FILE"
		dnf_list_version "$PKG_LIST_FILE"
		echo "${POST_SCRIPT-}"
	}
	_dnf_build_cb() {
		local CONTAINER="$1"
		run_dnf_with_list_file "$CONTAINER" "$PKG_LIST_FILE"
	}

	if [[ ${FORCE_DNF+found} != found ]]; then
		local FORCE_DNF=""
	fi

	BUILDAH_FORCE="$FORCE_DNF" buildah_cache2 "$CACHE_NAME" _dnf_hash_cb _dnf_build_cb
	unset -f _dnf_hash_cb _dnf_build_cb
}

function make_base_image_by_dnf() {
	local CACHE_NAME="$1"
	local PKG_LIST_FILE="$2"

	info "make base image by fedora dnf, package list file: $PKG_LIST_FILE..."

	_dnf_hash_cb() {
		cat "$PKG_LIST_FILE"
		dnf_list_version "$PKG_LIST_FILE"
		echo "${POST_SCRIPT-}"
	}
	_dnf_build_cb() {
		local CONTAINER="$1"
		run_dnf_with_list_file "$CONTAINER" "$PKG_LIST_FILE"
	}

	if [[ ${FORCE_DNF+found} != found ]]; then
		local FORCE_DNF=""
	fi

	BUILDAH_LAST_IMAGE="fedora:$FEDORA_VERSION"

	BUILDAH_FORCE="$FORCE_DNF" buildah_cache2 "$CACHE_NAME" _dnf_hash_cb _dnf_build_cb
	unset -f _dnf_hash_cb _dnf_build_cb
}

function run_dnf_with_list_file() {
	local WORKER="$1" LST_FILE="$2" PKGS
	mapfile -t PKGS <"$LST_FILE"
	run_dnf "$WORKER" "${PKGS[@]}"
}
function run_dnf() {
	local WORKING_CONTAINER="$1"
	shift

	local PACKAGES=("$@")
	local TMPSCRIPT ROOT

	local DNF # init in _dnf_prep
	_dnf_prep >&2

	control_ci group "DNF run (worker: $WORKING_CONTAINER, dnf worker: $DNF)"

	ROOT=$(buildah mount "$WORKING_CONTAINER")
	MNT_DNF=$(buildah mount "$DNF")
	mkdir -p "$ROOT/etc/yum.repos.d"
	rsync -rv "$MNT_DNF/etc/yum.repos.d/." "$ROOT/etc/yum.repos.d"
	rsync -rv "$COMMON_LIB_ROOT/staff/extra-repos/." "$ROOT/etc/yum.repos.d"
	[[ "$TMPREPODIR" ]] && [[ -e $TMPREPODIR ]] && rsync -rv "$TMPREPODIR/." "$ROOT/etc/yum.repos.d"
	info_note "using repos: " $(ls "$ROOT/etc/yum.repos.d")
	for D in bin sbin lib lib64; do
		if [[ ! -e "${ROOT}/$D" ]]; then
			mkdir -p "${ROOT}/usr/$D"
			ln -s "./usr/$D" "${ROOT}/$D"
		fi
	done

	buildah run "--volume=$ROOT:/install-root" "${DNF_RUN_ARGS[@]}" "$DNF" \
		dnf.sh "${PACKAGES[@]}"

	if [[ ${POST_SCRIPT-} ]]; then
		TMPSCRIPT=$(create_temp_file dnf.script.sh)
		{
			declare -p PACKAGES FEDORA_VERSION
			echo "${POST_SCRIPT}"
		} >"$TMPSCRIPT"
		chmod a+x "$TMPSCRIPT"
		buildah run "--volume=$TMPSCRIPT:/tmp/_script" "$WORKING_CONTAINER" \
			bash /tmp/_script
	fi
	buildah unmount "$WORKING_CONTAINER"
	buildah unmount "$DNF"

	echo "DNF run FINISH"
	control_ci groupEnd
}
function run_dnf_host() {
	local ACTION="$1" DNF DNF_CMD
	shift
	local PACKAGES=("$@")

	_dnf_prep >&2

	buildah run "${DNF_RUN_ARGS[@]}" "--env=ACTION=$ACTION" "$DNF" \
		dnf.sh "${PACKAGES[@]}"
}

function delete_rpm_files() {
	local CONTAINER="$1"
	buildah run "$CONTAINER" bash -c "rm -rf /var/lib/dnf /var/lib/rpm /var/cache"
}

function dnf_list_version() {
	local FILE=$1 PKGS=()

	mapfile -t PKGS <"$FILE"
	RET=$(run_dnf_host --quiet list --color never "${PKGS[@]}" | grep -v --fixed-strings i686 | grep --fixed-strings '.' | awk '{print $1 " = " $2}')
	echo "$RET"
	echo "=================================================" >&2
	echo "$RET" >&2
	echo "=================================================" >&2
}

function dnf() {
	die "deny run dnf on host!"
}

function dnf_add_repo_string() {
	local TITLE=$1 CONTENT=$2
	if [[ ! $TMPREPODIR ]]; then
		TMPREPODIR=$(create_temp_dir yum.repos.d)
		mkdir -p "$TMPREPODIR"
	fi
	echo "$CONTENT" >"$TMPREPODIR/${TITLE}.repo"
}
