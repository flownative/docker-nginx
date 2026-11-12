#!/usr/bin/env bash
#
# That uploaded files are never run by PHP, against the real Beach PHP image.
#
# Background: Flow publishes uploaded files below Web/_Resources/Persistent/.
# Nginx passed every URI ending in .php to PHP-FPM, and with cgi.fix_pathinfo=1
# PHP-FPM walks back the path to an existing file. A request for
# /_Resources/Persistent/<sha1>/upload.phar/x.php thus ran the uploaded file
# (.phar is in the default security.limit_extensions of PHP-FPM, and not in
# the upload blacklist of Flow).
#
# Every script below writes a marker; a response containing it means the file
# was run.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

CN=res-nginx
CP=res-php
VOL=res-application
PORT=18097
MARKER='EXEC-42'

cleanup() {
    docker rm -f "${CN}" "${CP}" >/dev/null 2>&1 || true
    docker volume rm "${VOL}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

require_image "${CANDIDATE_IMAGE}" || exit 1
require_image "${PHP_IMAGE}" || exit 1

heading "No PHP for uploaded files (${PHP_IMAGE})"
cleanup
create_application_volume "${VOL}"

# Both containers share /application, as in a Beach pod
docker run -d --name "${CN}" -p "${PORT}:8080" -v "${VOL}:/application" \
    -e BEACH_NGINX_CUSTOM_METRICS_ENABLE=true "${CANDIDATE_IMAGE}" >/dev/null
docker run -d --name "${CP}" --network "container:${CN}" -v "${VOL}:/application" "${PHP_IMAGE}" >/dev/null 2>&1
for _ in $(seq 1 30); do
    docker exec "${CN}" bash -c ': </dev/tcp/127.0.0.1/9000' 2>/dev/null && break
    sleep 2
done

docker exec "${CP}" sh -c '
    set -e
    script="<?php echo \"EXEC-\".(6*7);"
    mkdir -p /application/Web && cd /application/Web
    echo "<?php echo \"INDEX-OK\";" > index.php
    echo "${script}" > upload.phar
    mkdir -p _Resources/Persistent/0123456789abcdef0123456789abcdef01234567 _Resources/Static/Packages/Acme.Site
    echo "${script}" > _Resources/Persistent/0123456789abcdef0123456789abcdef01234567/poc.phar
    echo "${script}" > _Resources/Persistent/0123456789abcdef0123456789abcdef01234567/poc.php
    echo "${script}" > _Resources/Static/Packages/Acme.Site/poc.php
'
wait_for_http "http://localhost:${PORT}/index.php" 30 || fail "PHP did not come up"

persistent=/_Resources/Persistent/0123456789abcdef0123456789abcdef01234567

# check_not_run name path -- expects a 404 without the marker
check_not_run() {
    local body code
    body=$(curl -s "http://localhost:${PORT}$2")
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}$2")
    if [[ "${body}" == *"${MARKER}"* ]]; then
        fail "$1" "RUN by PHP: $2"
    else
        check_equals "$1" "${code}" "404"
    fi
}

echo "  Must not run:"
check_not_run "persistent .phar via path info" "${persistent}/poc.phar/x.php"
check_not_run "persistent .php" "${persistent}/poc.php"
check_not_run "static .php" "/_Resources/Static/Packages/Acme.Site/poc.php"
check_not_run ".phar via path info outside _Resources" "/upload.phar/x.php"
check_not_run "missing script" "/missing.php"

echo "  Must still work:"
check_equals "front page through index.php" "$(curl -s "http://localhost:${PORT}/")" "INDEX-OK"
check_equals "index.php directly" "$(curl -s "http://localhost:${PORT}/index.php?foo=bar")" "INDEX-OK"
check_equals "Flow route through index.php" "$(curl -s "http://localhost:${PORT}/neos/login")" "INDEX-OK"
check_equals "persistent resource is served as file" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}${persistent}/poc.phar")" "200"

echo "  Custom metrics server:"
body=$(docker exec "${CN}" bash -c "exec 3<>/dev/tcp/127.0.0.1/8082; printf 'GET ${persistent}/poc.phar/x.php HTTP/1.0\r\n\r\n' >&3; cat <&3")
if [[ "${body}" == *"${MARKER}"* ]]; then
    fail "metrics: persistent .phar via path info" "RUN by PHP"
else
    check_equals "metrics: persistent .phar via path info" "$(head -1 <<<"${body}" | tr -d '\r' | cut -d' ' -f2)" "404"
fi

heading "Result"
echo "  Failed: ${FAILS}"
exit "${FAILS}"
