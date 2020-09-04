function run_dnf() {
	local WORKER="$1"
	shift

	local MNT=$(buildah mount $WORKER)

	local DNF=$(CI="" create_if_not "mdnf" fedora)
	buildah copy "$DNF" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
	if [[ "${PROXY+found}" = found ]] && [[ "$PROXY" ]]; then
		info_warn "dnf is using proxy."
		buildah run "$DNF" sh -c "echo 'proxy=$PROXY' >> /etc/dnf/dnf.conf"
	else
		buildah run "$DNF" sh -c "sed -i '/proxy=/d' /etc/dnf/dnf.conf"
	fi
	info "dnf contianer created."
	buildah run "$DNF" bash < "$COMMON_LIB_ROOT/staff/mdnf/prepare.sh"

	mkdir -p /var/lib/dnf/repos /var/cache/dnf
	{
		cat "$COMMON_LIB_ROOT/staff/mdnf/bin.sh"
	} | buildah run \
		"--cap-add=CAP_SYS_ADMIN" \
		"--volume=$MNT:/install-root" \
		"--volume=/var/lib/dnf/repos:/var/lib/dnf/repos" \
		"--volume=/var/cache/dnf:/var/cache/dnf" \
		"$DNF" bash -s - "$@"
}

function delete_rpm_files() {
	local CONTAINER="$1"
	podman run "$CONTAINER" bash -c "rm -rf /var/lib/dnf /var/lib/rpm /var/cache"
}

function dev_dnf() {
	local CONTAINER="$1"
	shift
	buildah copy "$CONTAINER" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
	if [[ "${PROXY+found}" = found ]] && [[ "$PROXY" ]]; then
		buildah run "$CONTAINER" sh -c "echo 'proxy=$PROXY' >> /etc/dnf/dnf.conf"
	else
		buildah run "$CONTAINER" sh -c "sed -i '/^proxy=/d' /etc/dnf/dnf.conf"
	fi

	buildah run \
		--volume "/var/cache/dnf:/var/cache/dnf" \
		"$CONTAINER" /usr/bin/dnf install -y \
		"$@"
}
