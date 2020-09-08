function unit_podman_safe_environment() {
	unit_podman_arguments "$(safe_environment "$@")"
}

function safe_environment() {
	local D="$CONTAINERS_DATA_PATH/save_environments"
	local F="$D/$PROJECT_NAME.txt"
	mkdir -p "$D"

	local i
	echo -e "\e[2mPasthrough Environments:\e[0m" >&2
	echo -n > "$F"
	for i in "$@"; do
		echo "$i" >> "$F"
		echo -e "\e[2m    $i\e[0m" >&2
	done

	chmod 0700 "$D"
	find "$D" -type f | xargs chmod 0600

	echo -n "--env-file='$F'"
}

function save_environments() {
	local NAME=$1
	shift

	local D="$CONTAINERS_DATA_PATH/save_environments"
	local F="$D/$NAME.txt"
	mkdir -p "$D"

	local ARGS=("$@")
	{
		local i
		echo -n
		for i in "${ARGS[@]}"; do
			echo "$i"
		done
	} | write_file "$F"

	chmod 0700 "$D"
	find "$D" -type f | xargs chmod 0600

	echo -n "$F"
}
