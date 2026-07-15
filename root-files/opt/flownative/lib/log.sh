#!/bin/bash

# =======================================================================================
# LIBRARY: LOG
# =======================================================================================

# Ported from the Flownative bash-library, reduced to the functions used by this image.

export FLOWNATIVE_LOG_PATH_AND_FILENAME=${FLOWNATIVE_LOG_PATH_AND_FILENAME:-/dev/stdout}

# ---------------------------------------------------------------------------------------
# stderr_print() - Print to the log device
#
# @arg The message to print
# @return void
#
stderr_print() {
    printf "%b\\n" "${*}" >> "${FLOWNATIVE_LOG_PATH_AND_FILENAME}"
}

# ---------------------------------------------------------------------------------------
# debug() – Log a message with severity "debug"
#
# @arg The message to log
# @return void
#
debug() {
    local -r bool="${LOG_DEBUG:-false}"
    shopt -s nocasematch
    if [[ "$bool" == 1 || "$bool" =~ ^(yes|true)$ ]]; then
        log "[debug] ${*}"
    fi
}

# ---------------------------------------------------------------------------------------
# log() - Log a message
#
# @arg The message to log
# @return void
#
log() {
    stderr_print "${*}"
}

# ---------------------------------------------------------------------------------------
# info() - Log a message with severity "info"
#
# @arg The message to log
# @return void
#
info() {
    log "[info] ${*}"
}

# ---------------------------------------------------------------------------------------
# warn() - Log a message with severity "warning"
#
# @arg The message to log
# @return void
#
warn() {
    log "[warn] ${*}"
}

# ---------------------------------------------------------------------------------------
# error() - Log a message with severity "error"
#
# @arg The message to log
# @return void
#
error() {
    log "[error] ${*}"
}
