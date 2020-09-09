function _dnf_prep() {
	DNF=$(CI="" create_if_not "mdnf" fedora)
	buildah copy "$DNF" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
	if [[ "${PROXY+found}" = found ]] && [[ "$PROXY" ]]; then
		info_warn "dnf is using proxy."
		buildah run "$DNF" sh -c "echo 'proxy=$PROXY' >> /etc/dnf/dnf.conf"
	else
		buildah run "$DNF" sh -c "sed -i '/proxy=/d' /etc/dnf/dnf.conf"
	fi
	buildah run "$DNF" bash < "$COMMON_LIB_ROOT/staff/mdnf/prepare.sh"

	mkdir -p /var/lib/dnf/repos /var/cache/dnf
}

function use_fedora_dnf_cache() {
	echo "--volume=/var/lib/dnf/repos:/var/lib/dnf/repos" \
		"--volume=/var/cache/dnf:/var/cache/dnf"
}

function make_base_image_by_dnf() {
	local NAME="$1"
	shift
	local PKGS=("$@")

	_dnf_hash_cb() {
		echo "${PKGS[*]}" | md5sum
	}
	_dnf_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "scratch")
		run_dnf "$CONTAINER" "${PKGS[@]}"
	}

	if [[ "${FORCE_DNF+found}" != found ]]; then
		local FORCE_DNF=""
	fi

	BUILDAH_FORCE="$FORCE_DNF" buildah_cache "$NAME" _dnf_hash_cb _dnf_build_cb

	unset -f _dnf_hash_cb _dnf_build_cb
}

function run_dnf() {
	local WORKER="$1" DNF
	shift

	local MNT=$(buildah mount "$WORKER")
	_dnf_prep

	{
		cat "$COMMON_LIB_ROOT/staff/mdnf/bin.sh"
	} | buildah run \
		"--cap-add=CAP_SYS_ADMIN" \
		"--volume=$MNT:/install-root" \
		$(use_fedora_dnf_cache) \
		"$DNF" bash -s - "$@"
}

function delete_rpm_files() {
	local CONTAINER="$1"
	buildah run "$CONTAINER" bash -c "rm -rf /var/lib/dnf /var/lib/rpm /var/cache"
}
