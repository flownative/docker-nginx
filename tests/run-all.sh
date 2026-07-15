#!/usr/bin/env bash
#
# Führt alle Tests aus und fasst das Ergebnis zusammen.
#
#   CANDIDATE_IMAGE=flownative/nginx:local ./run-all.sh
#
# Einzelne Tests lassen sich auch direkt aufrufen.

set -o nounset

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

TESTS=(
    "1-render.sh"
    "2-nginx-t.sh"
    "3-runtime.sh"
    "4-php-fpm.sh"
    "5-logrotate.sh"
)

echo "Kandidat : ${CANDIDATE_IMAGE}"
echo "Referenz : ${REFERENCE_IMAGE}"
echo "PHP      : ${PHP_IMAGE}"

declare -a results=()
total=0

for t in "${TESTS[@]}"; do
    printf '\n\033[1m########## %s ##########\033[0m\n' "${t}"
    "./${t}"
    rc=$?
    total=$((total + rc))
    if [ "${rc}" -eq 0 ]; then
        results+=("  ok    ${t}")
    else
        results+=("  FAIL  ${t} (${rc} Fehler)")
    fi
done

printf '\n\033[1m########## Zusammenfassung ##########\033[0m\n'
printf '%s\n' "${results[@]}"
printf '\nFehler gesamt: %s\n' "${total}"
exit $(( total > 0 ? 1 : 0 ))
