#!/bin/bash

# function ___create_global_nginx_attach_mount(){
# 	local CONFIG_CONTENT="[Volume]
# Device=tmpfs
# Type=tmpfs
# Copy=false
# Options=size=32m
# VolumeName=nginx-attach-config

# [Service]
# Slice=services.slice
# "
# 	write_file "${PODMAN_QUADLET_DIR}/service-nginx-config.volume" "${CONFIG_CONTENT}"
# }
# register_unit_emit ___create_global_nginx_attach_mount
