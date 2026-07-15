#!/usr/bin/env bash
#
# Prüft für jede Env-Kombination, ob Nginx die gerenderte Config akzeptiert.
# Fängt Syntaxfehler und ein nicht ladbares headers_more-Modul ab.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

heading "nginx -t über die Matrix (${CANDIDATE_IMAGE})"
require_image "${CANDIDATE_IMAGE}" || exit 1

while IFS='|' read -r name envspec; do
    [ -z "${name}" ] && continue
    env_to_docker_args "${envspec}"

    if out=$(docker run --rm "${DOCKER_ARGS[@]}" "${CANDIDATE_IMAGE}" \
        bash -c '"${NGINX_BASE_PATH}/sbin/nginx" -t -c "${NGINX_CONF_PATH}/nginx.conf" -p "${NGINX_CONF_PATH}"' 2>&1); then
        pass "${name}"
    else
        fail "${name}" "$(grep -E 'emerg' <<<"${out}" | head -1)"
    fi
done <<<"${MATRIX}"

heading "Ergebnis"
echo "  Fehlgeschlagen: ${FAILS}"
exit "${FAILS}"
