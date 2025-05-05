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
# @global NGINX_* The NGINX_ environment variables
# @return "export" statements which can be passed to eval()
#
nginx_env() {
    cat <<"EOF"
export NGINX_BASE_PATH="${NGINX_BASE_PATH}"
export NGINX_CONF_PATH="${NGINX_BASE_PATH}/etc"
export NGINX_TMP_PATH="${NGINX_BASE_PATH}/tmp"
export NGINX_LOG_PATH="${NGINX_BASE_PATH}/log"
export NGINX_ERROR_LOG_LEVEL="${NGINX_ERROR_LOG_LEVEL:-${NGINX_LOG_LEVEL:-warn}}"
export NGINX_ACCESS_LOG_ENABLE="${NGINX_ACCESS_LOG_ENABLE:-false}"
export NGINX_ACCESS_LOG_MODE="${NGINX_ACCESS_LOG_MODE:-dynamic}"
export NGINX_ACCESS_LOG_FORMAT="${NGINX_ACCESS_LOG_FORMAT:-default}"
export NGINX_ACCESS_LOG_IGNORED_STATUS_CODES_REGEX="${NGINX_ACCESS_LOG_IGNORED_STATUS_CODES_REGEX:-^[13]}"

export NGINX_CACHE_PATH="${NGINX_CACHE_PATH:-${NGINX_BASE_PATH}/cache/application}"
export NGINX_CACHE_ENABLE="${NGINX_CACHE_ENABLE:-no}"
export NGINX_CACHE_NAME="${NGINX_CACHE_NAME:-application}"
export NGINX_CACHE_DEFAULT_LIFETIME="${NGINX_CACHE_DEFAULT_LIFETIME:-5s}"
export NGINX_CACHE_MAX_SIZE="${NGINX_CACHE_MAX_SIZE:-1024m}"
export NGINX_CACHE_INACTIVE="${NGINX_CACHE_INACTIVE:-1h}"
export NGINX_CACHE_USE_STALE_OPTIONS="${NGINX_CACHE_USE_STALE_OPTIONS:-updating error timeout invalid_header}"
export NGINX_CACHE_BACKGROUND_UPDATE="${NGINX_CACHE_BACKGROUND_UPDATE:-off}"

export NGINX_CACHE_RESOURCES_PATH="${NGINX_CACHE_RESOURCES_PATH:-${NGINX_BASE_PATH}/cache/resources}"

export NGINX_CUSTOM_ERROR_PAGE_CODES="${NGINX_CUSTOM_ERROR_PAGE_CODES:-500 501 502 503}"
export NGINX_CUSTOM_ERROR_PAGE_TARGET="${NGINX_CUSTOM_ERROR_PAGE_TARGET:-}"

export NGINX_STATIC_FILES_LIFETIME=${NGINX_STATIC_FILES_LIFETIME:-6M}

export PATH="${PATH}:${NGINX_BASE_PATH}/bin"
EOF
}

# ---------------------------------------------------------------------------------------
# nginx_config_fastcgi_cache() - Renders FastCGI configuration for a location block
#
# @global NGINX_* The NGINX_ environment variables
# @return void
#
nginx_config_fastcgi_cache() {
    cat << EOM
           fastcgi_cache ${NGINX_CACHE_NAME};
           fastcgi_cache_methods GET HEAD;
           fastcgi_cache_key \$request_method\$scheme\$host\$request_uri;
           fastcgi_cache_valid 200 301 302 ${NGINX_CACHE_DEFAULT_LIFETIME};
           fastcgi_cache_valid 404 410 30s;
           fastcgi_cache_use_stale ${NGINX_CACHE_USE_STALE_OPTIONS};
           fastcgi_cache_background_update ${NGINX_CACHE_BACKGROUND_UPDATE};

           set \$skipCache 0;
           if (\$http_cookie ~* "Neos_Session=([\w-]+)" ) {
             set \$skipCache 1;
           }

           fastcgi_no_cache \$skipCache;
           fastcgi_cache_bypass \$skipCache;

           add_header X-Nginx-Cache \$upstream_cache_status;
EOM
}

# ---------------------------------------------------------------------------------------
# nginx_config_fastcgi_custom_error_page() - Renders custom error page config for a location block
#
# @global NGINX_* The NGINX_ environment variables
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

    envsubst < "${NGINX_CONF_PATH}/nginx.conf.template" > "${NGINX_CONF_PATH}/nginx.conf"
    file_move_if_exists "${NGINX_CONF_PATH}/mime.types.template" "${NGINX_CONF_PATH}/mime.types"

    # Create a file descriptor for the Nginx stdout output and clean up the log
    # lines a bit:
    exec 4> >(sed -e "s/^\([0-9\/-]* [0-9:,]*\)/\1     OUTPUT Nginx:/")
}
