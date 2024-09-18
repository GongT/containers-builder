function mount_nginx_shared_config() {
	if [[ $(get_image_label "${LABELID_USE_NGINX_ATTACH}") == yes ]]; then
		info_log "create and mount nginx shared volume"
		NGINX_SHARED_VOLUME_ID=$(podman volume create --ignore --opt nocopy --opt device=tmpfs --opt type=tmpfs --opt o=size=32m nginx-attach)
		push_engine_param "--volume=${NGINX_SHARED_VOLUME_ID}:/run/nginx"
		push_engine_param "--env=NGINX_ROOT:/run/nginx"
	fi
}
