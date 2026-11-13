# 根据外部控制器传入的几个环境变量生成 /etc/systemd/resolved.conf

if [[ -e /etc/resolv.conf ]]; then
	mv /etc/resolv.conf /etc/resolv.conf.old || true
	unlink /etc/resolv.conf.old || true
fi

cat <<-EOF >/etc/systemd/resolved.conf
	[Resolve]
	FallbackDNS=${NSS-} 8.8.8.8
	Domains=$RESOLVE_SEARCH
	DNSSEC=no
	MulticastDNS=yes
	LLMNR=resolve
	Cache=yes
	CacheFromLocalhost=yes
	DNSStubListener=yes
	DNSStubListenerExtra=
	ReadEtcHosts=yes
	ResolveUnicastSingleLabel=yes
EOF

ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

log "已生成 /etc/resolv.conf 文件"
printf "%s\n" "$(</etc/resolv.conf)"  >&2
log "====="

unset NSS RESOLVE_SEARCH RESOLVE_OPTIONS
