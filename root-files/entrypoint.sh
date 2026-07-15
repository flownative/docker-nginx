#!/bin/bash
# shellcheck disable=SC1090

set -o errexit
set -o nounset
set -o pipefail

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/logrotate.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx-legacy.sh"

banner_flownative NGINX

eval "$(nginx_env)"
eval "$(nginx_legacy_env)"
eval "$(logrotate_env)"

nginx_initialize
nginx_legacy_initialize

if [[ "$*" = *"run"* ]]; then
    logrotate_start
    info "Entrypoint: Start up complete"
    # Nginx replaces this shell and becomes PID 1, so it receives SIGQUIT
    # (the STOPSIGNAL of this image) directly and shuts down gracefully.
    exec "${NGINX_BASE_PATH}/sbin/nginx" -c "${NGINX_CONF_PATH}/nginx.conf" -p "${NGINX_CONF_PATH}"
else
    "$@"
fi
