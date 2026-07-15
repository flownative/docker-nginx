#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: LOGROTATE
# =======================================================================================

# Nginx writes its access and error log to files below FLOWNATIVE_LOG_PATH, where
# log shippers like Promtail pick them up. Nothing rotates those files by itself,
# so logrotate is run periodically in the background.

. "${FLOWNATIVE_LIB_PATH}/log.sh"

# ---------------------------------------------------------------------------------------
# logrotate_env() - Load global environment variables for configuring logrotate
#
# @global LOGROTATE_* The LOGROTATE_ environment variables
# @return "export" statements which can be passed to eval()
#
logrotate_env() {
    cat <<"EOF"
export LOGROTATE_BASE_PATH="${LOGROTATE_BASE_PATH:-/opt/flownative/logrotate}"
export LOGROTATE_INTERVAL="${LOGROTATE_INTERVAL:-300}"
EOF
}

# ---------------------------------------------------------------------------------------
# logrotate_start() - Start the background loop rotating the Nginx logs
#
# The loop is started before Nginx replaces this shell via exec, so it ends up as a
# child of Nginx (PID 1) and is torn down with the container.
#
# @global LOGROTATE_* The LOGROTATE_ environment variables
# @return void
#
logrotate_start() {
    info "Logrotate: Rotating logs every ${LOGROTATE_INTERVAL} seconds ..."

    while true; do
        sleep "${LOGROTATE_INTERVAL}"
        logrotate \
            --state="${LOGROTATE_BASE_PATH}/var/status" \
            "${LOGROTATE_BASE_PATH}/etc/logrotate.conf" \
            || warn "Logrotate: Rotating logs failed"
    done &
}
