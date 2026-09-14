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

# SIGQUIT is the STOPSIGNAL of this image. This shell is PID 1, and PID 1
# ignores every signal it has no handler for, so without trapping SIGQUIT,
# "docker stop" and Kubernetes would run into their timeout and kill the
# container. syslog-ng is only stopped once supervisord has exited, so that
# the log lines Nginx writes while shutting down still make it to stdout.
trap 'supervisor_stop' SIGINT SIGTERM SIGQUIT

if [[ "$*" = *"run"* ]]; then
    supervisor_pid=$(supervisor_get_pid)
    info "Entrypoint: Start up complete"
    # We can't use "wait" because supervisord is not a direct child of this shell:
    while [ -e "/proc/${supervisor_pid}" ]; do sleep 1.1; done
    syslog_stop
    info "Good bye 👋"
else
    "$@"
fi
