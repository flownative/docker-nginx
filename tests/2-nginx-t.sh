#!/usr/bin/env bash
#
# Checks for every environment combination whether Nginx accepts the rendered
# configuration. Catches syntax errors and a headers_more module which cannot
# be loaded.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

heading "nginx -t across the matrix (${CANDIDATE_IMAGE})"
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

heading "Result"
echo "  Failed: ${FAILS}"
exit "${FAILS}"
