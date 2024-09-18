custom_reload_command "/usr/bin/bash" "/entrypoint/reload.sh"
buildah config "--label=${LABELID_USE_SYSTEMD}=yes" '--entrypoint=["/entrypoint/entrypoint.sh"]' '--cmd=["--systemd"]' "$1"
