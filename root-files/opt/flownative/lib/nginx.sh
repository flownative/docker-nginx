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
    if [ -f "${NGINX_TMP_PATH}/nginx.stopping" ]; then
        info "Skipping re-start of Nginx because it is currently being stopped"
        return
    fi

    info "Starting Nginx ..."

    "${NGINX_BASE_PATH}/sbin/nginx" -c "${NGINX_CONF_PATH}/nginx.conf"
}

# ---------------------------------------------------------------------------------------
# nginx_stop() - Stop the nginx process based on the current PID
#
# @global NGINX_* The NGINX_ evnironment variables
# @return void
#
nginx_stop() {
    local pid
    pid=$(nginx_get_pid)

    is_process_running "${pid}" || (info "Could not stop nginx, because the process was not running (detected pid: ${pid})" && return);

    info "Stopping nginx (pid ${pid}) ..."

    touch "${NGINX_TMP_PATH}/nginx.stopping"
    process_stop "${pid}"
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

    rm -f "${NGINX_TMP_PATH}/nginx.pid" "${NGINX_TMP_PATH}/nginx.stopping"
    envsubst < "${NGINX_CONF_PATH}/nginx.conf.template" > "${NGINX_CONF_PATH}/nginx.conf"
    file_move_if_exists "${NGINX_CONF_PATH}/mime.types.template" "${NGINX_CONF_PATH}/mime.types"
}
