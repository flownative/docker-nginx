#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Load library
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/os.sh"

# Load Nginx environment variables
eval "$(nginx_env)"

info "Starting Nginx ..."
with_backoff "${NGINX_BASE_PATH}/sbin/nginx -c ${NGINX_CONF_PATH}/nginx.conf"
