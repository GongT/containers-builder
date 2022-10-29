#!/usr/bin/env bash

REPO_CACHE_DIR="$SYSTEM_COMMON_CACHE/dnf-repos"

mkdir -p "$REPO_CACHE_DIR" "$SYSTEM_COMMON_CACHE/dnf"

TMPREPODIR=

function _dnf_prep() {
	DNF=$(create_if_not "mdnf" fedora)
	buildah copy "$DNF" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
	if [[ "${http_proxy:-}" ]]; then
		info_warn "dnf is using proxy $http_proxy."
		buildah run "$DNF" sh -c "echo 'proxy=$http_proxy' >> /etc/dnf/dnf.conf"
	else
		buildah run "$DNF" sh -c "sed -i '/proxy=/d' /etc/dnf/dnf.conf"
	fi


	# buildah run "$DNF" bash <"$COMMON_LIB_ROOT/staff/mdnf/prepare.sh"
}

function use_fedora_dnf_cache() {
	echo "--volume=$REPO_CACHE_DIR:/var/lib/dnf/repos" \
		"--volume=$SYSTEM_COMMON_CACHE/dnf:/var/cache/dnf"
}

function make_base_image_by_dnf() {
	local CACHE_NAME="$1"
	local PKG_LIST_FILE="$2"

	info "make base image by fedora dnf, package list file: $PKG_LIST_FILE..."

	_dnf_hash_cb() {
		cat "$PKG_LIST_FILE"
		dnf_list_version "$PKG_LIST_FILE"
		echo "${POST_SCRIPT:-}"
	}
	_dnf_build_cb() {
		local CONTAINER="$1"
		run_dnf_with_list_file "$CONTAINER" "$PKG_LIST_FILE"
	}

	if [[ ${FORCE_DNF+found} != found ]]; then
		local FORCE_DNF=""
	fi

	BUILDAH_LAST_IMAGE=scratch
	BUILDAH_FORCE="$FORCE_DNF" buildah_cache2 "$CACHE_NAME" _dnf_hash_cb _dnf_build_cb

	unset -f _dnf_hash_cb _dnf_build_cb
}

function run_dnf_with_list_file() {
	local WORKER="$1" LST_FILE="$2" PKGS
	mapfile -t PKGS <"$LST_FILE"
	run_dnf "$WORKER" "${PKGS[@]}"
}
function run_dnf() {
	local WORKER="$1" DNF DNF_CMD
	shift
	local PACKAGES=("$@")

	_dnf_prep

	control_ci group "DNF run ($DNF, worker: $WORKER)"
	DNF_CMD=$(create_temp_file dnf.cmd)
	cat <<-_EOF >"$DNF_CMD"
		#!/bin/bash
		set -Eeuo pipefail
		MNT=\$(buildah mount "$WORKER")
		MNT_DNF=\$(buildah mount "$DNF")
		mkdir -p "\$MNT/etc/yum.repos.d"
		cp -rn "\$MNT_DNF/etc/yum.repos.d/." "\$MNT/etc/yum.repos.d"
		rsync -rv "$COMMON_LIB_ROOT/staff/extra-repos/." "\$MNT/etc/yum.repos.d"
		[[ "$TMPREPODIR" ]] && [[ -e "$TMPREPODIR" ]] && rsync -rv "$TMPREPODIR/." "\$MNT/etc/yum.repos.d"
		# ls -l "\$MNT/etc/yum.repos.d"
		cd "\$MNT"
		for D in bin sbin lib lib64 ; do
			if [[ ! -e "\$D" ]]; then
				mkdir -p "usr/\$D"
				ln -s "usr/\$D" "./\$D"
			fi
		done
		cat << 'XXX' | buildah run --cap-add=CAP_SYS_ADMIN "--volume=\$MNT:/install-root" $(use_fedora_dnf_cache) "$DNF" bash -Eeuo pipefail
			$(declare -p PACKAGES)
			$(cat "$COMMON_LIB_ROOT/staff/mdnf/bin.sh")
			${POST_SCRIPT:-}
		XXX
		buildah unmount "$WORKER"
		buildah unmount "$DNF"
	_EOF
	unset POST_SCRIPT
	if is_root; then
		bash "$DNF_CMD"
	else
		buildah unshare bash "$DNF_CMD"
	fi
	echo "DNF run FINISH"
	control_ci groupEnd
}
function run_dnf_host() {
	local ACTION="$1" DNF DNF_CMD
	shift
	local PACKAGES=("$@")

	_dnf_prep

	{
		declare -p ACTION
		declare -p PACKAGES
		cat "$COMMON_LIB_ROOT/staff/mdnf/bin.sh"
	} | buildah run --cap-add=CAP_SYS_ADMIN $(use_fedora_dnf_cache) "$DNF" bash -Eeuo pipefail
}

function delete_rpm_files() {
	local CONTAINER="$1"
	buildah run "$CONTAINER" bash -c "rm -rf /var/lib/dnf /var/lib/rpm /var/cache"
}

function dnf_list_version() {
	local FILE=$1 PKGS=()

	mapfile -t PKGS <"$FILE"
	run_dnf_host list -q --color never "${PKGS[@]}" | grep -v --fixed-strings i686 | grep --fixed-strings '.' | awk '{print $1 " = " $2}'
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
