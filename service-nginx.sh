#!/bin/bash

# -----------------------------------------------------------------------------
# Define variables and their default values

export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH:-/application}
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH%/}
export BEACH_FLOW_BASE_CONTEXT=${BEACH_FLOW_BASE_CONTEXT:-Production}
if [ -z "${BEACH_FLOW_SUB_CONTEXT}" ]; then
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/Instance
else
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/${BEACH_FLOW_SUB_CONTEXT}
fi
export BEACH_FLOW_HTTP_TRUSTED_PROXIES=${BEACH_FLOW_HTTP_TRUSTED_PROXIES:-10.0.0.0/8}
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
export BEACH_NGINX_STATUS_PORT=${BEACH_NGINX_STATUS_PORT:-8080}

echo "Nginx mode is ${BEACH_NGINX_MODE} ..."

if [ "$BEACH_NGINX_MODE" == "Flow" ]; then
    echo "Enabling Flow site configuration ..."
    sudo -u www-data cat > /etc/nginx/sites-enabled/site.conf <<- EOM

server {

    listen *:80 default_server;

    root ${BEACH_APPLICATION_PATH}/Web;

    client_max_body_size 500M;
    index index.php;

    location ~ /\\.well-known/(.*)$ {
        allow all;
    }

    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    add_header Via '$hostname';

    try_files \$uri /index.php?\$args;

    location ~ \\.php\$ {
           include fastcgi_params;

           client_max_body_size 500M;

           fastcgi_pass ${BEACH_PHP_FPM_HOST}:${BEACH_PHP_FPM_PORT};
           fastcgi_index index.php;

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
        sudo -u www-data cat >> /etc/nginx/sites-enabled/site.conf <<- EOM
    location ~* ^${BEACH_PERSISTENT_RESOURCES_BASE_PATH}([a-f0-9]+)/ {
        resolver 8.8.8.8;
        proxy_set_header Authorization "";
        proxy_pass http://storage.googleapis.com/${BEACH_GOOGLE_CLOUD_STORAGE_PUBLIC_BUCKET}/\$1\$is_args\$args;
    }
EOM
    elif [ -n "${BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI}" ]; then
        sudo -u www-data cat >> /etc/nginx/sites-enabled/site.conf <<- EOM
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

    sudo -u www-data cat >> /etc/nginx/sites-enabled/site.conf <<- EOM
    location / {
        try_files \$uri /index.php?\$args;
    }

    location ~* \\.(jpg|jpeg|gif|css|png|js|ico|svg|woff|woff2|map)\$ {
           access_log off;
           expires max;
    }
}
EOM

else
    echo "Enabling default site configuration ..."
    sudo -u www-data cat > /etc/nginx/sites-enabled/default.conf <<- EOM
server {

    listen *:80 default_server;

    root /var/www/html;

    location ~ /\\. {
        access_log off;
        log_not_found off;
    }

}
EOM
fi

if [ "${BEACH_NGINX_STATUS_ENABLE}" == "true" ]; then
    echo "Enabling status endpoint /status on port ${BEACH_NGINX_STATUS_PORT} ..."
    sudo -u www-data cat > /etc/nginx/sites-enabled/default.conf <<- EOM
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

fi

exec /usr/sbin/nginx -g "daemon off;"
