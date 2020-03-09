
function safe_environment() {
	local D="$CONTAINERS_DATA_PATH/save_environments"
	local F="$D/$PROJECT_NAME.txt"
	mkdir -p "$D"
	
	local i
	echo -n > "$F"
	for i in "$@" ; do
		echo "$i" >> "$F"
	done
	
	chmod 0700 "$D"
	find "$D" -type f | xargs chmod 0600

	echo -n "--env-file='$F'"
}
