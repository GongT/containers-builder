function die() {
    echo "$@" >&2 ; exit 1
}
function info() {
    echo -e "\e[38;5;14m$*\e[0m" >&2
}
