declare -i DNS_TIMEOUT=$(cat /etc/resolv.conf | grep timeout | sed 's/.*timeout://g; s/\s.*$//g')
if [[ ${DNS_TIMEOUT} -lt 3 ]]; then
	DNS_TIMEOUT=3
fi
DNS_TIMEOUT=$((DNS_TIMEOUT + 5))

function _nslookup() {
	sdnotify --status="等待dns解析成功: lookup $1"
	expand_timeout_seconds "${DNS_TIMEOUT}"
	nslookup "$@"
}

declare -a NSS=()
function dns_resolve() {
	local -r METHOD="$1" HOSTN="$2"
	local RESOLVE_ARR RESOLVE_STR
	local -i I=5
	info_log "解析 DNS 主机: <${HOSTN}>"
	while true; do
		RESOLVE_STR=$(_nslookup "${HOSTN}" || :)
		if [[ -n ${RESOLVE_STR} ]]; then
			break
		fi
		if [[ ${I} -gt 0 ]]; then
			info_log "重试... (${I})"
			sleep 2
			I="${I} - 1"
			continue
		else
			die "解析 DNS 失败: ${HOSTN}"
		fi
	done
	mapfile -t RESOLVE_ARR < <(echo "${RESOLVE_STR}" | tail -n +3 | grep Address | sed 's/Address: //g')

	local ADDR
	for ADDR in "${RESOLVE_ARR[@]}"; do
		info_log " - 验证 DNS 服务器: ${ADDR}"
		if _nslookup -timeout=2 -retry=1 z.cn "${ADDR}" &>/dev/null; then
			dns_append "${METHOD}" "${ADDR}"
		fi
	done
}

function dns_pass() {
	local RESOLVE_OPTIONS="" RESOLVE_SEARCH="" RESOLVE_NS="" NS METHOD="${1-}"
	info_log "通过 ${METHOD} 传递 DNS 服务器"
	mapfile -t RESOLVE_OPTIONS < <(grep '^options ' /etc/resolv.conf | sed 's/^options //g')
	if [[ -n ${RESOLVE_OPTIONS[*]} ]]; then
		if [[ ${METHOD} == 'env' ]]; then
			push_engine_param "--env=RESOLVE_OPTIONS=${RESOLVE_OPTIONS[*]}"
		else
			push_engine_param "--dns-opt=${RESOLVE_OPTIONS[*]}"
		fi
	fi

	if [[ ${METHOD} == 'env' ]]; then
		mapfile -t RESOLVE_SEARCH < <(grep '^search ' /etc/resolv.conf | sed 's/^search //g')
		push_engine_param "--env=RESOLVE_SEARCH=${RESOLVE_SEARCH[*]}"
	fi

	mapfile -t RESOLVE_NS < <(grep '^nameserver ' /etc/resolv.conf | sed 's/^nameserver //g' | grep -Fv 127.0.0.1)
	dns_append "${METHOD}" "${RESOLVE_NS[@]}"
}

function dns_append() {
	local METHOD="${1}"
	shift

	info_log "$METHOD DNS 服务器: ${*}"

	if [[ ${METHOD} == 'env' ]]; then
		NSS+=("${@}")
		export NSS
	else
		local NS
		for NS in "${@}"; do
			push_engine_param "--dns=${NS}"
		done
	fi
}

function dns_finalize() {
	if [[ ${#NSS[@]} -gt 0 ]]; then
		push_engine_param "--env=NSS=${NSS[*]}"
	fi
}
