#!/bin/bash

# =======================================================================================
# LIBRARY: BANNER
# =======================================================================================

# Some ANSI color escape codes:
#
#  0 | Reset / normal       | All attributes off
# 38 | Set foreground color | Next arguments are 5;<n> or 2;<r>;<g>;<b>
# 48 | Set background color | Next arguments are 5;<n> or 2;<r>;<g>;<b>

export BANNER_FLOWNATIVE_SKIP=${BANNER_FLOWNATIVE_SKIP:-}

# ---------------------------------------------------------------------------------------
# banner_flownative() - Display a Flownative banner
#
# @return void
#
banner_flownative() {
    local -r image_name="${1:?missing image name}"

    if [ "${BANNER_FLOWNATIVE_SKIP}" = "" ]; then
        echo '[38;5;255;255;255m        [0m[38;5;7m                                             [0m'
        echo "[38;5;196;48;5;196m       [0m[38;5;255;255;255m   $(printf "%-41s" "${image_name}") [0m"
        echo '[38;5;196;48;5;196m       [0m[38;5;7m   This Docker image was handcrafted for you [0m'
        echo '[38;5;196;48;5;196m       [0m[38;5;7m   by Flownative.         www.flownative.com [0m'
        echo '[38;5;255;255;255m        [0m[38;5;7m                                             [0m'
    fi
}

# ---------------------------------------------------------------------------------------
# banner_generic() - Display a generic banner
#
# @arg string The title
# @arg string An optional description line
# @arg string A second optional description line
# @return void
#
banner_generic() {
    local -r title="${1:?missing title}"
    local -r description_1="${2:-}"
    local -r description_2="${3:-}"

    if [ "${BANNER_FLOWNATIVE_SKIP}" = "" ]; then
        echo '[38;5;255;255;255m        [0m[38;5;7m                                                                 [0m'
        echo "[38;5;196;48;5;196m       [0m[38;5;255;255;255m   $(printf "%-61s" "${title}") [0m"
        echo "[38;5;196;48;5;196m       [0m[38;5;7m   $(printf "%-61s" "${description_1}") [0m"
        echo "[38;5;196;48;5;196m       [0m[38;5;7m   $(printf "%-61s" "${description_2}") [0m"
        echo '[38;5;255;255;255m        [0m[38;5;7m                                                                 [0m'
    fi
}
