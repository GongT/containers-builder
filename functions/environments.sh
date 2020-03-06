
function safe_environment() {
	local F=/data/AppData/save_environments/$PROJECT_NAME.txt
	mkdir -p /data/AppData/save_environments
	
	local i
	echo -n > "$F"
	for i in "$@" ; do
		echo "$i" >> "$F"
	done
	
	chmod 0700 /data/AppData/save_environments
	find /data/AppData/save_environments -type f | xargs chmod 0600

	echo -n "--env-file='$F'"
}
