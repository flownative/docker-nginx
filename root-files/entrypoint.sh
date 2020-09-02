#!/bin/bash
# shellcheck disable=SC1090

set -o errexit
set -o nounset
set -o pipefail

. "${FLOWNATIVE_LIB_PATH}/syslog-ng.sh"
. "${FLOWNATIVE_LIB_PATH}/supervisor.sh"
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx-legacy.sh"

banner_flownative NGINX

eval "$(syslog_env)"
syslog_initialize
syslog_start

eval "$(nginx_env)"
eval "$(nginx_legacy_env)"
eval "$(supervisor_env)"

nginx_initialize
nginx_legacy_initialize

supervisor_initialize
supervisor_start

trap 'supervisor_stop; syslog_stop' SIGINT SIGTERM

if [[ "$*" = *"run"* ]]; then
    supervisor_pid=$(supervisor_get_pid)
    info "Entrypoint: Start up complete"
    # We can't use "wait" because supervisord is not a direct child of this shell:
    while [ -e "/proc/${supervisor_pid}" ]; do sleep 1.1; done
    info "Good bye 👋"
else
    "$@"
fi
