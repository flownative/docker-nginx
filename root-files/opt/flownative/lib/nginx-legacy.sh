#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: NGINX LEGACY
# =======================================================================================

# This library provides full backwards-compatibility to the earlier nginx images
# based on BEACH_* environment variables. In the long run, the functionality found in
# here should be refactored into a cleaner, more universal approach.

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"

# ---------------------------------------------------------------------------------------
# nginx_legacy_env() - Load global environment variables for configuring Nginx
#
# @global NGINX_* The NGINX_ evnironment variables
# @return "export" statements which can be passed to eval()
#
nginx_legacy_env() {
    cat <<"EOF"
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH:-/application}
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH%/}
export BEACH_FLOW_BASE_CONTEXT=${BEACH_FLOW_BASE_CONTEXT:-Production}
export BEACH_FLOW_SUB_CONTEXT=${BEACH_FLOW_SUB_CONTEXT:-}
if [ -z "${BEACH_FLOW_SUB_CONTEXT}" ]; then
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/Instance
else
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/${BEACH_FLOW_SUB_CONTEXT}
fi

export FLOW_HTTP_TRUSTED_PROXIES=${FLOW_HTTP_TRUSTED_PROXIES:-}
if [ -z "${FLOW_HTTP_TRUSTED_PROXIES}" ]; then
    export FLOW_HTTP_TRUSTED_PROXIES=${BEACH_FLOW_HTTP_TRUSTED_PROXIES:-10.0.0.0/8,127.0.0.1/32,172.16.0.0/12}
fi

export BEACH_GOOGLE_CLOUD_STORAGE_TARGET_BUCKET=${BEACH_GOOGLE_CLOUD_STORAGE_TARGET_BUCKET:-}
if [ -z "${BEACH_GOOGLE_CLOUD_STORAGE_TARGET_BUCKET}" ]; then
    export BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET=${BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET:-}
else
    export BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET=${BEACH_GOOGLE_CLOUD_STORAGE_TARGET_BUCKET}
fi
export BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI=${BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI:-}
export BEACH_PERSISTENT_RESOURCES_BASE_PATH=${BEACH_PERSISTENT_RESOURCES_BASE_PATH:-/_Resources/Persistent/}
export BEACH_PHP_FPM_HOST=${BEACH_PHP_FPM_HOST:-localhost}
export BEACH_PHP_FPM_PORT=${BEACH_PHP_FPM_PORT:-9000}
export BEACH_NGINX_MODE=${BEACH_NGINX_MODE:-Flow}
export BEACH_NGINX_STATUS_ENABLE=${BEACH_NGINX_STATUS_ENABLE:-true}
export BEACH_NGINX_STATUS_PORT=${BEACH_NGINX_STATUS_PORT:-8081}

export BEACH_NGINX_CUSTOM_METRICS_ENABLE=${BEACH_NGINX_CUSTOM_METRICS_ENABLE:-false}
export BEACH_NGINX_CUSTOM_METRICS_SOURCE_PATH=${BEACH_NGINX_CUSTOM_METRICS_SOURCE_PATH:-/metrics}
export BEACH_NGINX_CUSTOM_METRICS_TARGET_PORT=${BEACH_NGINX_CUSTOM_METRICS_TARGET_PORT:-8082}

export NGINX_CUSTOM_ERROR_PAGE_TARGET=${NGINX_CUSTOM_ERROR_PAGE_TARGET:-${BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET:-}}

export NGINX_STRICT_TRANSPORT_SECURITY_ENABLE=${NGINX_STRICT_TRANSPORT_SECURITY_ENABLE:-no}
export NGINX_STRICT_TRANSPORT_SECURITY_PRELOAD=${NGINX_STRICT_TRANSPORT_SECURITY_PRELOAD:-no}
export NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE=${NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE:-31536000}

export NGINX_AUTH_BASIC_REALM=${NGINX_AUTH_BASIC_REALM:-off}
export NGINX_AUTH_BASIC_USERNAME=${NGINX_AUTH_BASIC_USERNAME:-}
export NGINX_AUTH_BASIC_ENCODED_HASHED_PASSWORD=${NGINX_AUTH_BASIC_ENCODED_HASHED_PASSWORD:-}

export NGINX_STATIC_ROOT=${NGINX_STATIC_ROOT:-/var/www/html}
EOF
}

# ---------------------------------------------------------------------------------------
# nginx_legacy_initialize_flow() - Set up Nginx configuration for a Flow application
#
# @global NGINX_* The NGINX_* environment variables
# @return void
#
nginx_legacy_initialize_flow() {
    info "Nginx: Enabling Flow site configuration ..."

    addHeaderStrictTransportSecurity=""
    if is_boolean_yes "${NGINX_STRICT_TRANSPORT_SECURITY_ENABLE}"; then
        if is_boolean_yes "${NGINX_STRICT_TRANSPORT_SECURITY_PRELOAD}"; then
            info "Nginx: Enabling Strict Transport Security with preloading, max-age=${NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE} ..."
            addHeaderStrictTransportSecurity="add_header Strict-Transport-Security \"max-age=${NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE}; preload\" always;"
        else
            info "Nginx: Enabling Strict Transport Security without preloading, max-age=${NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE} ..."
            addHeaderStrictTransportSecurity="add_header Strict-Transport-Security \"max-age=${NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE}\" always;"
        fi
    fi

    cat >"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM

server {
    listen *:8080 default_server;

    root ${BEACH_APPLICATION_PATH}/Web;

    client_max_body_size 500M;

    if (\$http_user_agent ~* (citrixreceiver)) {
        return 403;
    }

    # allow .well-known/... in root
    location ~ ^/\\.well-known/.+ {
        allow all;
        add_header Via '\$hostname' always;
    }

    # deny files starting with a dot (having "/." in the path)
    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location = /site.webmanifest {
        log_not_found off;
        access_log off;
        expires ${NGINX_STATIC_FILES_LIFETIME};
    }

    location ~ ^/(android-chrome-.+|apple-touch-icon|favicon.*|mstile-.+|safari-pinned-tab).(png|svg|jpg|ico)$ {
        log_not_found off;
        access_log off;
        expires ${NGINX_STATIC_FILES_LIFETIME};
    }

EOM

    if [ "${NGINX_AUTH_BASIC_REALM}" != "off" ]; then
        info "Nginx: Enabling HTTP Basic Auth with realm ${NGINX_AUTH_BASIC_REALM} ..."
        NGINX_AUTH_BASIC_HASHED_PASSWORD=$(echo "${NGINX_AUTH_BASIC_ENCODED_HASHED_PASSWORD}" | base64 -d)

    cat >"${NGINX_CONF_PATH}/.htpasswd" <<-EOM
${NGINX_AUTH_BASIC_USERNAME}:${NGINX_AUTH_BASIC_HASHED_PASSWORD}
EOM

    cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
            auth_basic "${NGINX_AUTH_BASIC_REALM}";
            auth_basic_user_file "${NGINX_CONF_PATH}/.htpasswd";
EOM
    fi

    cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
    location ~ \\.php\$ {
           include fastcgi_params;

           client_max_body_size 500M;

           add_header Via '\$hostname' always;
           ${addHeaderStrictTransportSecurity}

           fastcgi_pass ${BEACH_PHP_FPM_HOST}:${BEACH_PHP_FPM_PORT};
           fastcgi_index index.php;
EOM
    if [ -n "${NGINX_CUSTOM_ERROR_PAGE_TARGET}" ]; then
        info "Nginx: Enabling custom error page pointing to ${BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET} ..."
        nginx_config_fastcgi_custom_error_page >>"${NGINX_CONF_PATH}/sites-enabled/site.conf"
    fi
    cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
           fastcgi_param FLOW_CONTEXT ${BEACH_FLOW_CONTEXT};
           fastcgi_param FLOW_REWRITEURLS 1;
           fastcgi_param FLOW_ROOTPATH ${BEACH_APPLICATION_PATH};
           fastcgi_param FLOW_HTTP_TRUSTED_PROXIES ${FLOW_HTTP_TRUSTED_PROXIES};

           fastcgi_split_path_info ^(.+\\.php)(.*)\$;
           fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
           fastcgi_param PATH_INFO \$fastcgi_path_info;

EOM
    if is_boolean_yes "${NGINX_CACHE_ENABLE}"; then
        info "Nginx: Enabling FastCGI cache ..."
        nginx_config_fastcgi_cache >>"${NGINX_CONF_PATH}/sites-enabled/site.conf"
    fi

    cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
    }
EOM

    if [ -n "${BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET}" ]; then
        cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
    # redirect "subdivided" persistent resource requests to remove the subdivision parts
    # e.g. _Resources/Persistent/1/2/3/4/123456789… to _Resources/Persistent/123456789…
    location ~* "^${BEACH_PERSISTENT_RESOURCES_BASE_PATH}(?:[0-9a-f]/){4}([0-9a-f]{40}/.*)" {
        return 301 \$scheme://\$host${BEACH_PERSISTENT_RESOURCES_BASE_PATH}\$1;
    }
    # pass persistent resource requests to GCS
    location ~* "^${BEACH_PERSISTENT_RESOURCES_BASE_PATH}([a-f0-9]{40})/" {
        resolver 8.8.8.8;
        proxy_set_header Authorization "";
        add_header Via 'Beach Asset Proxy';
        ${addHeaderStrictTransportSecurity}
        proxy_pass https://storage.googleapis.com/${BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET}/\$1\$is_args\$args?reqid=\$request_id;
        expires ${NGINX_STATIC_FILES_LIFETIME};
    }
EOM
    elif [ -n "${BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI}" ]; then
        cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
    location ~* "^${BEACH_PERSISTENT_RESOURCES_BASE_PATH}(.*)$" {
        access_log off;
        expires ${NGINX_STATIC_FILES_LIFETIME};
        add_header Via '\$hostname' always;
        ${addHeaderStrictTransportSecurity}
        try_files \$uri @fallback;
    }

    location @fallback {
        set \$assetUri ${BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI}\$1;
        add_header Via 'Beach Asset Fallback';
        ${addHeaderStrictTransportSecurity}
        resolver 8.8.8.8;
        proxy_pass \$assetUri;
    }
EOM
    else
        cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
    location ~* ^/_Resources/Persistent/(.*)$ {
        access_log off;
        expires ${NGINX_STATIC_FILES_LIFETIME};
        add_header Via '\$hostname' always;
        ${addHeaderStrictTransportSecurity}
        try_files \$uri -404;
    }
EOM
    fi

    cat >>"${NGINX_CONF_PATH}/sites-enabled/site.conf" <<-EOM
    # everything is tried as file first, then passed on to index.php (i.e. Flow)
    location / {
        add_header Via '\$hostname' always;
        try_files \$uri /index.php?\$args;
    }

    # for all static resources
    location ~ ^/_Resources/Static/ {
        add_header X-Static-Resource '\$hostname' always;
        access_log off;
        expires ${NGINX_STATIC_FILES_LIFETIME};
    }
}
EOM
}

# ---------------------------------------------------------------------------------------
# nginx_legacy_initialize_static() - Set up Nginx configuration for a static site
#
# @global NGINX_* The NGINX_* environment variables
# @return void
#
nginx_legacy_initialize_static() {
    info "Nginx: Enabling static site configuration with root at ${NGINX_STATIC_ROOT} ..."
    cat >"${NGINX_CONF_PATH}/sites-enabled/default.conf" <<-EOM
server {
    listen *:8080 default_server;

    root ${NGINX_STATIC_ROOT};

    # deny files starting with a dot (having "/." in the path)
    location ~ /\\. {
        access_log off;
        log_not_found off;
    }
}
EOM
}

# ---------------------------------------------------------------------------------------
# nginx_legacy_initialize_status() - Set up Nginx configuration an server block / site
#
# @global NGINX_* The NGINX_* environment variables
# @global BEACH_* The BEACH_* environment variables
# @return void
#
nginx_legacy_initialize_status() {
        info "Nginx: Enabling status endpoint / status on port ${BEACH_NGINX_STATUS_PORT} ..."
        cat >"${NGINX_CONF_PATH}/sites-enabled/status.conf" <<-EOM
server {

    listen *:${BEACH_NGINX_STATUS_PORT};

    location = /status {
        stub_status;
        allow all;
    }

    location / {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOM

        if [ "${BEACH_NGINX_CUSTOM_METRICS_ENABLE}" == "true" ]; then
            info "Nginx: Enabling custom metrics endpoint on port ${BEACH_NGINX_CUSTOM_METRICS_TARGET_PORT} ..."
            cat >"${NGINX_CONF_PATH}/sites-enabled/custom_metrics.conf" <<-EOM
server {
    listen *:${BEACH_NGINX_CUSTOM_METRICS_TARGET_PORT};

    root /application/Web;

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ${BEACH_NGINX_CUSTOM_METRICS_SOURCE_PATH} {
      try_files \$uri /index.php?\$args;
    }

    location ~ \\.php\$ {
        include fastcgi_params;

        fastcgi_pass ${BEACH_PHP_FPM_HOST}:${BEACH_PHP_FPM_PORT};
        fastcgi_index index.php;

        fastcgi_param FLOW_CONTEXT ${BEACH_FLOW_CONTEXT};
        fastcgi_param FLOW_REWRITEURLS 1;
        fastcgi_param FLOW_ROOTPATH ${BEACH_APPLICATION_PATH};
        fastcgi_param FLOW_HTTP_TRUSTED_PROXIES ${FLOW_HTTP_TRUSTED_PROXIES};

        fastcgi_param FLOWNATIVE_PROMETHEUS_ENABLE true;

        fastcgi_split_path_info ^(.+\\.php)(.*)\$;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOM

        fi
}

# ---------------------------------------------------------------------------------------
# nginx_legacy_initialize() - Set up Nginx configuration an server block / site
#
# @global NGINX_* The NGINX_* environment variables
# @return void
#
nginx_legacy_initialize() {
    info "Nginx: Setting up site configuration ..."

    info "Nginx: Mode is ${BEACH_NGINX_MODE}"

    if [ "$BEACH_NGINX_MODE" == "Flow" ]; then
        nginx_legacy_initialize_flow
    else
        nginx_legacy_initialize_static
    fi

    if [ "${BEACH_NGINX_STATUS_ENABLE}" == "true" ]; then
        nginx_legacy_initialize_status
    fi
}
