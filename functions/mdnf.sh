function run_dnf() {
	local WORKER="$1"
	shift

	local MNT=$(buildah mount $WORKER)

	local DNF=$(create_if_not "mdnf" fedora)
	buildah copy "$DNF" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
	if [[ "${PROXY+found}" = found ]] && [[ "$PROXY" ]]; then
		buildah run "$DNF" sh -c "echo 'proxy=$PROXY' >> /etc/dnf/dnf.conf"
	fi
	info "dnf contianer created."

	{
		echo "declare -a ARGS=($*)"
		echo "declare -r WORKER='$WORKER'"
		cat "$COMMON_LIB_ROOT/staff/mdnf/bin.sh"
	} | buildah run \
		--volume "$MNT:/install-root" \
		--volume "/var/cache/dnf:/var/cache/dnf" \
		--volume "/var/cache/dnf:/install-root/var/cache/dnf" \
		"$DNF" bash
}

function dev_dnf() {
	local CONTAINER="$1"
	shift
	buildah copy "$CONTAINER" "$COMMON_LIB_ROOT/staff/mdnf/dnf.conf" /etc/dnf/dnf.conf
	if [[ "$PROXY" ]]; then
		buildah run "$CONTAINER" sh -c "echo 'proxy=$PROXY' >> /etc/dnf/dnf.conf"
	else
		buildah run "$CONTAINER" sh -c "sed -i '/^proxy=/d' /etc/dnf/dnf.conf"
	fi

	buildah run \
		--volume "/var/cache/dnf:/var/cache/dnf" \
		"$CONTAINER" /usr/bin/dnf install -y \
		"$@"
}
