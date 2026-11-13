function find_podman0_ip() {
	podman network inspect podman | grep -oE '"gateway": ".+",?$' | sed 's/"gateway": "\(.*\)".*/\1/g' | head -1
}

declare HOST_IP=""
function detect_host_ip() {
	if [[ ${NETWORK_TYPE} == "host" ]]; then
		HOST_IP="127.0.0.1"
	elif [[ ${NETWORK_TYPE} == "nat" ]]; then
		HOST_IP=$(find_podman0_ip)
		if [[ -z ${HOST_IP} ]]; then
			critical_die "无法获取默认 podman 网络 (podman0) 的信息，podman 配置似乎失败了。"
		fi
	else
		HOST_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
	fi

	info_log "本地主机访问地址: ${HOST_IP}"
	push_engine_param "--env=HOSTIP=${HOST_IP}"
}
