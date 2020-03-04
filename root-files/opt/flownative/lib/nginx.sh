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
    "${NGINX_BASE_PATH}/sbin/nginx" -c "${NGINX_CONF_PATH}/nginx.conf" &

    sleep 1
    while [ ! -f "${NGINX_TMP_PATH}/nginx.pid" ]; do
        info "Nginx: Waiting for nginx.pid to appear"
        sleep 1
    done

    info "Nginx: Running as process #$(nginx_get_pid)"
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
