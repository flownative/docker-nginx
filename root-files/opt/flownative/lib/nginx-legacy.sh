#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: NGINX LEGACY
# =======================================================================================

# This library provides full backwards-compatibility to the earlier nginx images
# based on BEACH_* environment variables. In the long run, the functionality found in
# here should be refactored into a cleaner, more universal approach.

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"

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
export BEACH_FLOW_HTTP_TRUSTED_PROXIES=${BEACH_FLOW_HTTP_TRUSTED_PROXIES:-10.0.0.0/8}

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

export BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET=${BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET:-}
EOF
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
        info "Nginx: Enabling Flow site configuration ..."
        cat > "${NGINX_CONF_PATH}/sites-enabled/site.conf" <<- EOM

server {
    listen *:8080 default_server;

    root ${BEACH_APPLICATION_PATH}/Web;

    client_max_body_size 500M;

    # allow .well-known/... in root
    location ~ ^/\\.well-known/.+ {
        allow all;
    }

    # deny files starting with a dot (having "/." in the path)
    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    add_header Via '\$hostname';

    location ~ \\.php\$ {
           include fastcgi_params;

           client_max_body_size 500M;

           fastcgi_pass ${BEACH_PHP_FPM_HOST}:${BEACH_PHP_FPM_PORT};
           fastcgi_index index.php;

EOM
        if [ -n "${BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET}" ]; then
        info "Nginx: Enabling custom error page pointing to ${BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET} ..."
        cat >> "${NGINX_CONF_PATH}/sites-enabled/site.conf" <<- EOM
           fastcgi_intercept_errors on;
           error_page 500 501 502 503 ${BEACH_NGINX_CUSTOM_ERROR_PAGE_TARGET};
EOM
        fi
        cat >> "${NGINX_CONF_PATH}/sites-enabled/site.conf" <<- EOM
           fastcgi_param FLOW_CONTEXT ${BEACH_FLOW_CONTEXT};
           fastcgi_param FLOW_REWRITEURLS 1;
           fastcgi_param FLOW_ROOTPATH ${BEACH_APPLICATION_PATH};
           fastcgi_param FLOW_HTTP_TRUSTED_PROXIES ${BEACH_FLOW_HTTP_TRUSTED_PROXIES};

           fastcgi_split_path_info ^(.+\\.php)(.*)\$;
           fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
           fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
EOM

        if [ -n "${BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET}" ]; then
            cat >> "${NGINX_CONF_PATH}/sites-enabled/site.conf" <<- EOM
    location ~* ^${BEACH_PERSISTENT_RESOURCES_BASE_PATH}([a-f0-9]+)/ {
        resolver 8.8.8.8;
        proxy_set_header Authorization "";
        proxy_pass http://storage.googleapis.com/${BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET}/\$1\$is_args\$args;
    }
EOM
        elif [ -n "${BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI}" ]; then
            cat >> "${NGINX_CONF_PATH}/sites-enabled/site.conf" <<- EOM
    location ~* ^/_Resources/Persistent/(.*)$ {
        access_log off;
        expires max;
        try_files \$uri @fallback;
    }

    location @fallback {
        set \$assetUri ${BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI}\$1;
        add_header Via 'Beach Asset Fallback';
        resolver 8.8.8.8;
        proxy_pass \$assetUri;
    }
EOM

        fi

        cat >> "${NGINX_CONF_PATH}/sites-enabled/site.conf" <<- EOM
    # everything is tried as file first, then passed on to index.php (i.e. Flow)
    location / {
        try_files \$uri /index.php?\$args;
    }

    # for all static resources
    location ~ ^/_Resources/Static/ {
        access_log off;
        expires max;
    }
}
EOM

    else
        info "Nginx: Enabling default site configuration ..."
        cat > "${NGINX_CONF_PATH}/sites-enabled/default.conf" <<- EOM
server {
    listen *:8080 default_server;

    root /var/www/html;

    # deny files starting with a dot (having "/." in the path)
    location ~ /\\. {
        access_log off;
        log_not_found off;
    }
}
EOM
    fi

    if [ "${BEACH_NGINX_STATUS_ENABLE}" == "true" ]; then
        info "Nginx: Enabling status endpoint / status on port ${BEACH_NGINX_STATUS_PORT} ..."
        cat > "${NGINX_CONF_PATH}/sites-enabled/status.conf" <<- EOM
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
          cat > "${NGINX_CONF_PATH}/sites-enabled/custom_metrics.conf" <<- EOM
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
        fastcgi_param FLOW_HTTP_TRUSTED_PROXIES ${BEACH_FLOW_HTTP_TRUSTED_PROXIES};

        fastcgi_param FLOWNATIVE_PROMETHEUS_ENABLE true;

        fastcgi_split_path_info ^(.+\\.php)(.*)\$;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOM

      fi
    fi
}
