PODMAN=$(find_command podman || die "podman not installed")
declare -rx PODMAN
BUILDAH=$(find_command buildah || die "buildah not installed")
declare -rx BUILDAH
