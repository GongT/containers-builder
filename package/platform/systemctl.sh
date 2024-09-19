SYSTEMCTL=/usr/bin/systemctl

if is_root; then
	declare -r _SYSC_TYPE='--system'
else
	declare -r _SYSC_TYPE='--user'

	SYSTEMD_ANALYZE=$(command -v systemd-analyze)
	function systemd-analyze() {
		"${SYSTEMD_ANALYZE}" --user "$@"
	}
fi

declare -a SYSTEMD_SHOULD_ENABLED=()
function systemctl() {
	x "${SYSTEMCTL}" "$_SYSC_TYPE" "$@"
}
function add_service_to_enable() {
	SYSTEMD_SHOULD_ENABLED+=("$@")
}

function host_systemd_enable_service() {
	local UN=$1
	if is_installing; then
		if ! systemctl is-enabled -q "$UN"; then
			systemctl enable "${UN}" &>/dev/null || true
		fi
	else
		if systemctl is-enabled -q "$UN"; then
			systemctl disable --now "${UN}" &>/dev/null || true
			systemctl reset-failed "${UN}" &>/dev/null || true
		fi
	fi
}

function ___finalize_daemon_reloaded() {
	local FILE
	for FILE in "${ALL_CHANGED_FILES[@]}"; do
		if file_in_folder "${FILE}" "${SYSTEM_UNITS_DIR}"; then
			info_success "systemd units file changed, auto reload."
			systemctl daemon-reload
			delete_file 0 "${PRIVATE_CACHE}/remember-service-list.txt"
			break
		fi
	done

	if [[ ${#SYSTEMD_SHOULD_ENABLED[@]} -gt 0 ]]; then
		local UN
		for UN in "${SYSTEMD_SHOULD_ENABLED[@]}"; do
			host_systemd_enable_service "${UN}"
		done
	fi
}

register_exit_handler ___finalize_daemon_reloaded

function uptime_sec() {
	local T
	T=$(awk '{print $1}' /proc/uptime)
	printf "%.0f" "${T}"
}
function timespan_seconds() {
	local span=$1
	local -i us
	if [[ $span == infinity ]]; then
		printf '-1'
	elif us=$(systemd-analyze timespan "${span}" | grep 'μs:' | awk '{print $2}'); then
		printf "%.0f" $((us / microsecond_unit))
	else
		printf '-1'
	fi
}
function seconds_timespan() {
	local -i sec=$1
	local h

	systemd-analyze timespan "${sec}s" | grep -F 'Human:' | sed -E 's/\s*Human:\s*//; s/min/m/'
}

declare -ri microsecond_unit=1000000

function systemd_service_property() {
	systemctl show "$1" "--property=$2" --value
}
