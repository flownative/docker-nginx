#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Load library
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"

# Load Nginx environment variables
eval "$(nginx_env)"

exec "${NGINX_BASE_PATH}/sbin/nginx" -c "${NGINX_CONF_PATH}/nginx.conf"
