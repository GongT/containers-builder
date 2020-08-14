echo -ne "\ec"

echo -ne "\e[2m"
printf '=%.0s' $(seq 1 ${COLUMNS-80})
echo ""
systemctl cat $SERVICE_FILE --no-pager | sed -E "s/^/\x1B[2m/mg" || true

if echo "$SCOPE_ID" | grep -q '%i'; then
	template_id=$1
	shift

	if ! [[ "$template_id" ]]; then
		echo "for template (instantiated / ending with @) service, the first argument is the %i value."
		exit 1
	fi

	function X() {
		local PODMAN_RUN=()
		for i; do
			PODMAN_RUN+=($(echo "$i" | sed "s/%i/${template_id}/g"))
		done
		XX "${PODMAN_RUN[@]}" "${PARENT_ARGS[@]}"
	}

else

	function X() {
		XX "${@}" "${PARENT_ARGS[@]}"
	}

fi

declare -a PARENT_ARGS=("$@")

function find_bridge_ip() {
	podman network inspect podman | grep -oE '"gateway": ".+",?$' | sed 's/"gateway": "\(.*\)".*/\1/g'
}

function XX() {
	local ARGS=("$@")
	echo -ne "\e[2m"
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	echo
	echo -n "$1"
	for i in $(seq 2 $(($#))); do
		if [[ "${ARGS[$i]}" == "--dns=h.o.s.t" ]]; then
			ARGS[$i]="--dns=$(find_bridge_ip)"
		fi
		echo -ne " \\\\\n  "
		echo -n "'${ARGS[$i]}'"
	done
	echo
	printf '=%.0s' $(seq 1 ${COLUMNS-80})
	echo -e "\e[0m"

	exec "${ARGS[@]}"
}

# append
