#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: VALIDATION
# =======================================================================================

# Ported from the Flownative bash-library, reduced to the functions used by this image.

# ---------------------------------------------------------------------------------------
# is_boolean_yes() - Checks if the given argument is a bool or if it's "true" or "yes" or "on"
#
# @arg Value to check
# @return bool
#
is_boolean_yes() {
    local -r bool="${1:-}"
    shopt -s nocasematch
    if [[ "$bool" = 1 || "$bool" =~ ^(yes|true|on)$ ]]; then
        true
    else
        false
    fi
}
