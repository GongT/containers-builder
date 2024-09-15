declare -a PODMAN_EXEC_ARGS=()
function push_engine_param() {
	# info_note "add argument '$*'"
	PODMAN_EXEC_ARGS+=("$@")
}
push_engine_param "--log-level=info"
push_engine_param "--restart=no"

function make_arguments() {
	detect_host_ip

	readonly COMMAND_LINE
	local COMBINED_ARGS=("${ENGINE_PARAMS[@]}" "${PODMAN_IMAGE_NAME[@]}" "${COMMAND_LINE[@]}")

	if [[ -n ${INVOCATION_ID-} ]]; then
		push_engine_param "--env=INVOCATION_ID=${INVOCATION_ID}"
		push_engine_param "--annotation=systemd.service.invocation_id=${INVOCATION_ID}"
	fi

	local i
	for i in "${COMBINED_ARGS[@]}"; do
		if [[ ${i} == "--dns=h.o.s.t" ]]; then
			if [[ -z ${HOST_IP} ]]; then
				critical_die "Try to use h.o.s.t when network type is ${NETWORK_TYPE}, this is currently not supported."
			fi
			push_engine_param "--dns=${HOST_IP}"
		elif [[ ${i} == "--dns=p.a.s.s" ]]; then
			dns_pass argument
		elif [[ ${i} == "--dns-env=p.a.s.s" ]]; then
			dns_pass env
		elif [[ ${i} == "--dns="* ]]; then
			if ip route get "${i#--dns=}" &>/dev/null; then
				push_engine_param "${i}"
			else
				dns_resolve argument "${i#--dns=}"
			fi
		elif [[ ${i} == "--dns-env="* ]]; then
			if ip route get "${i#--dns-env=}" &>/dev/null; then
				push_engine_param "${i}"
			else
				dns_resolve env "${i#--dns-env=}"
			fi
		else
			push_engine_param "${i}"
		fi
	done

	dns_finalize
}
