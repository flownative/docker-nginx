#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Load lib
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx-legacy.sh"

eval "$(nginx_env)"
eval "$(nginx_legacy_env)"

banner_flownative NGINX

if [[ "$*" = *"run"* ]]; then
    nginx_initialize
    nginx_legacy_initialize
    nginx_start
    # This line will be reached only after Nginx was stopped
else
    "$@"
fi
