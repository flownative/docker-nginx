#!/usr/bin/env bash
#
# Prüft, dass die Logdateien rotiert werden -- ohne Rotation läuft das
# log-Volume voll, das sich Nginx mit dem Promtail-Addon teilt.
#
# Achtung beim Anpassen: "maxsize 50M" meint 52.428.800 Bytes. Eine Datei mit
# 52.000.000 Bytes löst die Rotation NICHT aus.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

C=lr-test
MAXSIZE_BYTES=52428800

cleanup() { docker rm -f "${C}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

require_image "${CANDIDATE_IMAGE}" || exit 1

heading "Logrotate"
cleanup
# Kurzes Intervall, damit der Loop im Test mehrfach zum Zug kommt
docker run -d --name "${C}" -e LOGROTATE_INTERVAL=5 "${CANDIDATE_IMAGE}" >/dev/null
sleep 4

check_equals "Nginx ist PID 1" "$(docker exec "${C}" cat /proc/1/comm 2>/dev/null)" "nginx"
check_present "logrotate-Loop läuft als Kind von PID 1" \
    "$(docker exec "${C}" sh -c 'ps -o ppid,args 2>/dev/null | grep -c "^ *1 .*entrypoint.sh"' || echo 0)"

echo "  Datei über maxsize bringen ($((MAXSIZE_BYTES + 2000000)) Bytes) ..."
docker exec "${C}" sh -c "head -c $((MAXSIZE_BYTES + 2000000)) /dev/zero | tr '\\0' 'x' > /opt/flownative/log/nginx-access.log"

echo "  Auf den Loop warten ..."
rotated=0
for _ in $(seq 1 8); do
    sleep 3
    if docker exec "${C}" sh -c 'test -f /opt/flownative/log/nginx-access.log.1'; then rotated=1; break; fi
done

check_equals "Loop rotiert autonom" "${rotated}" "1"
check_equals "neue Logdatei ist leer" \
    "$(docker exec "${C}" sh -c 'wc -c < /opt/flownative/log/nginx-access.log' | tr -d ' ')" "0"
check_present "rotierte Generation existiert" \
    "$(docker exec "${C}" sh -c 'ls /opt/flownative/log/nginx-access.log.1 2>/dev/null | wc -l' | tr -d ' ')"

heading "Ergebnis"
echo "  Fehlgeschlagen: ${FAILS}"
exit "${FAILS}"
