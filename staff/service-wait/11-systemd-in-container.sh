function detect_image_using_systemd() {
	# push_engine_param "--log-driver=passthrough"
	push_engine_param "--attach=stdin,stdout,stderr"
	push_engine_param "--log-driver=none"
	push_engine_param "--tty"

	if [[ ${FORCE_SYSTEMD-} == "true" ]] || is_image_using_systemd; then
		info_log "image is systemd: forced=${FORCE_SYSTEMD-false}, label=$(get_image_label "${LABELID_SYSTEMD}")"
		push_engine_param '--systemd=always' '--privileged=true'
	else
		push_engine_param '--systemd=false'
	fi
}
