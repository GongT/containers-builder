declare -ra INPUT_ARGUMENTS=("$@")
declare -a ARGS=()
function add_run_argument() {
	ARGS=("$@" "${ARGS[@]}")
}
add_run_argument "--log-level=info"
add_run_argument "--restart=no"

function make_arguments() {
	detect_host_ip

	if [[ -n ${INVOCATION_ID-} ]]; then
		add_run_argument "--env=INVOCATION_ID=${INVOCATION_ID}"
		add_run_argument "--annotation=systemd.service.invocation_id=${INVOCATION_ID}"
	fi

	local i
	for i in "${INPUT_ARGUMENTS[@]}"; do
		if [[ ${i} == "--dns=h.o.s.t" ]]; then
			if [[ -z ${HOST_IP} ]]; then
				critical_die "Try to use h.o.s.t when network type is ${NETWORK_TYPE}, this is currently not supported."
			fi
			ARGS+=("--dns=${HOST_IP}")
		elif [[ ${i} == "--dns=p.a.s.s" ]]; then
			dns_pass argument
		elif [[ ${i} == "--dns-env=p.a.s.s" ]]; then
			dns_pass env
		elif [[ ${i} == "--dns="* ]]; then
			if ip route get "${i#--dns=}" &>/dev/null; then
				ARGS+=("${i}")
			else
				dns_resolve argument "${i#--dns=}"
			fi
		elif [[ ${i} == "--dns-env="* ]]; then
			if ip route get "${i#--dns-env=}" &>/dev/null; then
				ARGS+=("${i}")
			else
				dns_resolve env "${i#--dns-env=}"
			fi
		else
			ARGS+=("${i}")
		fi
	done

	dns_finalize
}
