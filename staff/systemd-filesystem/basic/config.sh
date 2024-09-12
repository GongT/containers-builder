buildah config "--label=${LABELID_SYSTEMD}=yes" '--entrypoint=["/entrypoint/entrypoint.sh"]' '--cmd=["--systemd"]' "$1"
