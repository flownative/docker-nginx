#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: NGINX
# =======================================================================================

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"

# ---------------------------------------------------------------------------------------
# nginx_env() - Load global environment variables for configuring Nginx
#
# @global NGINX_* The NGINX_ evnironment variables
# @return "export" statements which can be passed to eval()
#
nginx_env() {
    cat <<"EOF"
export NGINX_BASE_PATH="${NGINX_BASE_PATH}"
export NGINX_CONF_PATH="${NGINX_CONF_PATH:-${NGINX_BASE_PATH}/etc}"
export NGINX_TMP_PATH="${NGINX_TMP_PATH:-${NGINX_BASE_PATH}/tmp}"
export NGINX_LOG_PATH="${NGINX_LOG_PATH:-${NGINX_BASE_PATH}/log}"
EOF
}

# ---------------------------------------------------------------------------------------
# nginx_conf_validate() - Validates configuration options passed as NGINX_* env vars
#
# @global NGINX_* The NGINX_* environment variables
# @return void
#
#nginx_conf_validate() {
#    echo ""
#}

# ---------------------------------------------------------------------------------------
# nginx_initialize() - Initialize Nginx configuration and check required files and dirs
#
# @global NGINX_* The NGINX_* environment variables
# @return void
#
nginx_initialize() {
    info "Initializing Nginx ..."

#    nginx_conf_validate

    rm -f "${NGINX_TMP_PATH}/nginx.pid"
    envsubst < "${NGINX_CONF_PATH}/nginx.conf.template" > "${NGINX_CONF_PATH}/nginx.conf"
    mv "${NGINX_CONF_PATH}/mime.types.template" "${NGINX_CONF_PATH}/mime.types"
}
