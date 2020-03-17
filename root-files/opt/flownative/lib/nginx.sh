#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: NGINX
# =======================================================================================

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/files.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/process.sh"

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
export NGINX_LOG_LEVEL="${NGINX_LOG_LEVEL:-warn}"

export NGINX_CACHE_PATH="${NGINX_CACHE_PATH:-${NGINX_BASE_PATH}/cache}"
export NGINX_CACHE_ENABLE="${NGINX_CACHE_ENABLE:-no}"
export NGINX_CACHE_NAME="${NGINX_CACHE_NAME:-application}"
export NGINX_CACHE_DEFAULT_LIFETIME="${NGINX_CACHE_DEFAULT_LIFETIME:-5s}"
export NGINX_CACHE_MAX_SIZE="${NGINX_CACHE_MAX_SIZE:-1024m}"
export NGINX_CACHE_INACTIVE="${NGINX_CACHE_INACTIVE:-1h}"
export NGINX_CACHE_USE_STALE_OPTIONS="${NGINX_CACHE_USE_STALE_OPTIONS:-updating error timeout invalid_header}"
export NGINX_CACHE_BACKGROUND_UPDATE="${NGINX_CACHE_BACKGROUND_UPDATE:-off}"

export NGINX_CUSTOM_ERROR_PAGE_TARGET="${NGINX_CUSTOM_ERROR_PAGE_TARGET:-}"
EOF
}

# ---------------------------------------------------------------------------------------
# nginx_get_pid() - Return the nginx process id
#
# @global NGINX_* The NGINX_ evnironment variables
# @return Returns the Nginx process id, if it is running, otherwise 0
#
nginx_get_pid() {
    local pid
    pid=$(process_get_pid_from_file "${NGINX_TMP_PATH}/nginx.pid")

    if [[ -n "${pid}" ]]; then
        echo "${pid}"
    else
        false
    fi
}

# ---------------------------------------------------------------------------------------
# nginx_start() - Start Nginx
#
# @global NGINX_* The NGINX_ evnironment variables
# @return void
#
nginx_start() {
    local pid
    trap 'nginx_stop' EXIT

    info "Nginx: Starting ..."

    with_backoff "${NGINX_BASE_PATH}/sbin/nginx -c ${NGINX_CONF_PATH}/nginx.conf" || error "Nginx: Failed starting process"
}

# ---------------------------------------------------------------------------------------
# nginx_stop() - Stop the nginx process based on the current PID
#
# @global NGINX_* The NGINX_ evnironment variables
# @return void
#
nginx_stop() {
    info "Nginx: Stopping ..."
    # Nginx reacts to signals automatically, so no need for us to stop it explicitly
}

# ---------------------------------------------------------------------------------------
# nginx_config_fastcgi_custom_error_page() - Renders custom error page config for a location block
#
# @global NGINX_* The NGINX_ evnironment variables
# @return void
#
nginx_config_fastcgi_custom_error_page() {
        cat << EOM
           fastcgi_intercept_errors on;
           error_page ${NGINX_CUSTOM_ERROR_PAGE_CODES} ${NGINX_CUSTOM_ERROR_PAGE_TARGET};
EOM
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
    info "Nginx: Initializing ..."

#    nginx_conf_validate

    envsubst < "${NGINX_CONF_PATH}/nginx.conf.template" > "${NGINX_CONF_PATH}/nginx.conf"
    file_move_if_exists "${NGINX_CONF_PATH}/mime.types.template" "${NGINX_CONF_PATH}/mime.types"
}
