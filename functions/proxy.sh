function run_without_proxy() {
	local HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= http_proxy= https_proxy= all_proxy=
	"$@"
}
