#!/bin/bash

# Define defaults:
export BEACH_CLUSTER_TYPE=${BEACH_CLUSTER_TYPE:-compose}

export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH:-/application}
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH%/}

export BEACH_FLOW_BASE_CONTEXT=${BEACH_FLOW_BASE_CONTEXT:-Production}
if [ -z ${BEACH_INSTANCE_IDENTIFIER} ]; then
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/Cluster
else
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/Instance/${BEACH_INSTANCE_IDENTIFIER}
fi

export BEACH_PHP_FPM_HOST=${BEACH_PHP_FPM_HOST:-localhost}
export BEACH_PHP_FPM_PORT=${BEACH_PHP_FPM_PORT:-9000}

export BEACH_NGINX_MODE=${BEACH_NGINX_MODE:-Flow}

echo "Nginx mode is ${BEACH_NGINX_MODE} ..."

if [ "$BEACH_NGINX_MODE" == "Flow" ]; then
    echo "Enabling Flow site configuration ..."
    sudo -u www-data cat > /etc/nginx/sites-enabled/site.conf <<- EOM

server {

    listen *:80 default_server;

    root ${BEACH_APPLICATION_PATH}/Web;

    client_max_body_size 100M;
    index index.php;

    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    try_files \$uri \$uri/ /index.php?\$args;

    location ~ \\.php\$ {
           include fastcgi_params;

           client_max_body_size 100M;

           fastcgi_pass ${BEACH_PHP_FPM_HOST}:${BEACH_PHP_FPM_PORT};
           fastcgi_index index.php;

           fastcgi_param FLOW_CONTEXT ${BEACH_FLOW_CONTEXT};
           fastcgi_param FLOW_REWRITEURLS 1;
           fastcgi_param FLOW_ROOTPATH ${BEACH_APPLICATION_PATH};

           fastcgi_split_path_info ^(.+\\.php)(.*)\$;
           fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
           fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~* \\.(jpg|jpeg|gif|css|png|js|ico|svg|woff|map)\$ {
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

exec /usr/sbin/nginx -g "daemon off;"
