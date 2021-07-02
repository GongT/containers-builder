REPO_CACHE_DIR="$SYSTEM_COMMON_CACHE/dnf-repos"

mkdir -p "$REPO_CACHE_DIR" "$SYSTEM_COMMON_CACHE/dnf"

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
		dnf_hash_version "$PKG_LIST_FILE"
		echo "${POST_SCRIPT:-}"
	}
	_dnf_build_cb() {
		local CONTAINER="$1"
		run_dnf_with_list_file "$CONTAINER" "$PKG_LIST_FILE"
		if [[ ${POST_SCRIPT+found} == found ]]; then
			"$POST_SCRIPT" "$CONTAINER"
			unset POST_SCRIPT
		fi
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

	control_ci group "DNF run"
	DNF_CMD=$(create_temp_file dnf.cmd)
	cat <<-_EOF >"$DNF_CMD"
		#!/bin/bash
		set -Eeuo pipefail
		MNT=\$(buildah mount "$WORKER")
		cat << 'XXX' | buildah run --cap-add=CAP_SYS_ADMIN "--volume=\$MNT:/install-root" $(use_fedora_dnf_cache) "$DNF" bash -Eeuo pipefail
		$(declare -p PACKAGES)
		$(cat "$COMMON_LIB_ROOT/staff/mdnf/bin.sh")
		XXX
		buildah rm "$WORKER"
	_EOF
	buildah unshare bash "$DNF_CMD"
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

function dnf_hash_version() {
	local CACHE_DIR="$SYSTEM_FAST_CACHE/dnf-version-cache"
	local PKGS=() FILE=$1 MISSING=() NAME SUM=""
	local MASTER_HASH_FILE="$CACHE_DIR/.master"

	mapfile -t PKGS <"$FILE"
	mkdir -p "$CACHE_DIR"

	local DNF_REPO_STAT
	DNF_REPO_STAT=$(find "$REPO_CACHE_DIR" | sort)

	if [[ -f $MASTER_HASH_FILE ]] && echo "$DNF_REPO_STAT" | md5sum -c "$MASTER_HASH_FILE" --status; then
		info_log "dnf version cache is valid."
		for NAME in "${PKGS[@]}"; do
			if ! [[ -f "$CACHE_DIR/$NAME" ]]; then
				MISSING+=("${NAME}")
			fi
		done
	else
		MISSING=("${PKGS[@]}")
		info_warn "[dnf] version cache invalid..."
		find "$CACHE_DIR" -type f -exec rm '{}' \;
		echo "$DNF_REPO_STAT" | md5sum >"$MASTER_HASH_FILE"
	fi

	if [[ ${#MISSING[@]} -gt 0 ]]; then
		info_log "finding ${#MISSING[@]} packages version..."
		local NEW_VERSIONS=() E VER
		mapfile -t NEW_VERSIONS < <(run_dnf_host list --color never "${MISSING[@]}" | grep -v i686)
		for E in "${NEW_VERSIONS[@]}"; do
			NAME=$(echo "$E" | awk '{print $1}')
			VER=$(echo "$E" | awk '{print $2}')
			NAME="${NAME%.*}"
			echo "$VER" >"$CACHE_DIR/$NAME"
		done
	fi

	for NAME in "${PKGS[@]}"; do
		if [[ -f "$CACHE_DIR/$NAME" ]]; then
			SUM+="$(<"$CACHE_DIR/$NAME")"
		else
			info_warn "missing version about package \"$NAME\""
		fi
	done

	echo "$SUM" | md5sum | awk '{print $1}'
}

function dnf() {
	die "deny run dnf on host!"
}
