#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: FILES
# =======================================================================================

# Ported from the Flownative bash-library, reduced to the functions used by this image.

. "${FLOWNATIVE_LIB_PATH}/log.sh"

# ---------------------------------------------------------------------------------------
# file_move_if_exists() - Moves a file if it exists, otherwise does nothing
#
# @arg The full path and filename if the source file
# @arg The target path or path and filename
# @return void
#
file_move_if_exists() {
    local -r source="${1:?missing source path and filename}"
    local -r target="${2:?missing target path and filename}"

    if [ -f "${source}" ]; then
        mv "${source}" "${target}"
    else
        debug "Not moving '$source', because the file does not exist"
    fi
}
