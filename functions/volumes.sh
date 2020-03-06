function use_volume() {
	podman volume inspect $1 --format "{{.Mountpoint}}" || {
		podman volume create $1
		podman volume inspect $1 --format "{{.Mountpoint}}"
	}
}

function _bind_anon() {
	echo -n "\"--volume=$1:$2\""
}

function bind() {
	if [[ "${1:0:1}" == "/" ]] ; then
		if echo "$1" | grep -qE '/.+\..+$' ; then
			mkdir -p "$(dirname "$1")"
			touch "$1"
		else
			mkdir -p "$1"
		fi
		_bind_anon "$1" "$2"
	else
		if ! podman volume inspect "$1" &>/dev/null ; then
			echo -e "\e[38;5;9mRequired volume $1 is not exists. must run create-volume.sh first.\e[0m" >&2
		fi
		
		_bind_anon "$1" "$2"
	fi
}
