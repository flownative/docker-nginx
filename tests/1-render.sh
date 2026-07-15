#!/usr/bin/env bash
#
# Der Kerntest: rendert die Nginx-Config beider Images über die gesamte
# Env-Variablen-Matrix und vergleicht sie zeilenweise.
#
# Der Vertrag dieses Images ist "die dokumentierten Variablen verhalten sich
# unverändert". Genau das prüft dieser Test: die gerenderte Config muss
# byte-identisch sein, bis auf die bewusst geänderten Zeilen (siehe
# ACCEPTED_DIFF).

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

OUTDIR="${OUTDIR:-./out}"

# Zeilen, deren Abweichung erwartet und beabsichtigt ist:
#   error_log / access_log  -> zusätzliche Ausgabe nach stdout/stderr
#   fastcgi_pass            -> Default BEACH_PHP_FPM_HOST localhost -> 127.0.0.1
#   keys_zone               -> folgt jetzt NGINX_CACHE_NAME statt hartkodiert
ACCEPTED_DIFF='error_log|access_log|fastcgi_pass|keys_zone'

# ---------------------------------------------------------------------------
# render() - Rendert alle Configs eines Images in ein Verzeichnis
#
render() { # image, outdir
    local image="$1" outdir="$2" name envspec
    mkdir -p "${outdir}"
    while IFS='|' read -r name envspec; do
        [ -z "${name}" ] && continue
        env_to_docker_args "${envspec}"
        # Ein anderes Argument als "run" führt der Entrypoint nach der
        # Initialisierung aus -- die Configs sind dann bereits gerendert.
        docker run --rm "${DOCKER_ARGS[@]}" "${image}" \
            bash -c 'for f in "${NGINX_CONF_PATH}"/nginx.conf "${NGINX_CONF_PATH}"/sites-enabled/*.conf; do
                         [ -e "$f" ] || continue
                         echo "===== $(basename "$f") ====="
                         cat "$f"
                     done' \
            >"${outdir}/${name}.conf" 2>"${outdir}/${name}.stderr"
        printf '.'
    done <<<"${MATRIX}"
    printf '\n'
}

# ---------------------------------------------------------------------------
# clean() - Entfernt alles aus dem Stream, was keine Config ist
#
# Der Entrypoint loggt via info() nach /dev/stdout, sein Banner ebenso; beides
# landet im selben Stream wie die Config. Kommentare werden entfernt, damit
# reine Kommentaränderungen den Vergleich nicht verrauschen.
#
clean() {
    grep -v '^\[info\]' "$1" \
        | sed -e 's/\x1b\[[0-9;]*m//g' \
        | grep -vE '^\s*#' \
        | grep -v '^ *$' \
        | grep -vE 'Flownative|handcrafted|www\.flownative\.com|^ *NGINX *$'
}

heading "Configs rendern: ${REFERENCE_IMAGE}"
require_image "${REFERENCE_IMAGE}" || exit 1
render "${REFERENCE_IMAGE}" "${OUTDIR}/reference"

heading "Configs rendern: ${CANDIDATE_IMAGE}"
require_image "${CANDIDATE_IMAGE}" || exit 1
render "${CANDIDATE_IMAGE}" "${OUTDIR}/candidate"

heading "Vergleich"

unexpected=0
while IFS='|' read -r name _; do
    [ -z "${name}" ] && continue
    ref="${OUTDIR}/reference/${name}.conf"
    cand="${OUTDIR}/candidate/${name}.conf"

    # Ist das Rendern überhaupt gelungen? Auf den gefilterten Inhalt prüfen:
    # bricht der Entrypoint ab, enthält die Datei zwar noch Banner und
    # [info]-Zeilen, aber keine Config.
    if [ ! -s "${cand}" ] || [ -z "$(clean "${cand}")" ]; then
        fail "${name}" "Kandidat rendert nicht: $(tail -1 "${OUTDIR}/candidate/${name}.stderr")"
        continue
    fi
    if [ ! -s "${ref}" ] || [ -z "$(clean "${ref}")" ]; then
        # Die Referenz kann kaputt sein -- 4.13.1 bricht im Static-Mode mit
        # "underScoresInHeadersDirective: unbound variable" ab.
        pass "${name}" "nur Kandidat rendert (Referenz bricht ab)"
        continue
    fi

    diff_out=$(diff <(clean "${ref}") <(clean "${cand}") | grep -E '^[<>]' || true)
    unexpected_lines=$(grep -vE "${ACCEPTED_DIFF}" <<<"${diff_out}" | grep -E '^[<>]' || true)

    if [ -z "${diff_out}" ]; then
        pass "${name}" "identisch"
    elif [ -z "${unexpected_lines}" ]; then
        pass "${name}" "$(grep -c '^[<>]' <<<"${diff_out}") erwartete Abweichung(en)"
    else
        fail "${name}" "unerwartete Abweichung:"
        sed 's/^/         /' <<<"${unexpected_lines}"
        unexpected=$((unexpected + 1))
    fi
done <<<"${MATRIX}"

heading "Ergebnis"
echo "  Unerwartete Abweichungen: ${unexpected}"
echo "  Rohdaten unter: ${OUTDIR}/"
exit "${FAILS}"
