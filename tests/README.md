# Tests

Die CI baut dieses Image, ohne es je zu starten. Diese Tests schließen die
Lücke: Sie starten das gebaute Image wirklich und vergleichen es gegen das
**zuletzt released Image** statt gegen fest verdrahtete Erwartungswerte.

Der Vertrag, den sie absichern: *die in der README dokumentierten
Environment-Variablen behalten Namen, Defaults und Wirkung.* Wer an der
Config-Generierung schraubt, sollte sie vorher und nachher laufen lassen.

Entstanden sind sie beim Umstieg auf das offizielle `nginx:alpine`-Image.

## Voraussetzungen

- Docker
- Bash 4+ (unter macOS: `brew install bash`, das mitgelieferte 3.2 reicht nicht)
- Netzwerkzugriff auf Harbor bzw. Docker Hub für Referenz- und PHP-Image

## Ausführen

```bash
# Image bauen (aus diesem Verzeichnis heraus)
docker build -t flownative/nginx:local ..

# Alles ausführen (dauert einige Minuten, startet viele Container)
./run-all.sh

# Oder einzeln
./1-render.sh
```

Konfiguration über Environment-Variablen:

| Variable | Default | Bedeutung |
|---|---|---|
| `CANDIDATE_IMAGE` | `flownative/nginx:local` | Das zu testende Image |
| `REFERENCE_IMAGE` | `harbor.flownative.io/docker/nginx:latest` | Vergleichsbasis (nur `1-render.sh`) |
| `PHP_IMAGE` | `flownative/beach-php:8.4` | PHP-FPM fürs End-to-End (nur `4-php-fpm.sh`) |

Jedes Skript endet mit der Anzahl der Fehler als Exit-Code, `run-all.sh` mit 0
oder 1.

## Die Tests

| Skript | Was es prüft |
|---|---|
| `1-render.sh` | **Der Kerntest.** Rendert die Config beider Images über die gesamte Variablen-Matrix und vergleicht zeilenweise. Alles außer den bewusst geänderten Zeilen muss identisch sein. |
| `2-nginx-t.sh` | `nginx -t` über dieselbe Matrix. Fängt Syntaxfehler und ein nicht ladbares `headers_more` ab. |
| `3-runtime.sh` | Echte Requests: Auslieferung, Status-Endpoint, `more_set_headers`, Logging in Datei *und* Stream, Shutdown. |
| `4-php-fpm.sh` | End-to-End gegen das echte `beach-php`-Image, inklusive Startup-Rennen. |
| `5-logrotate.sh` | Dass die Logdateien autonom rotiert werden. |

`lib.sh` enthält die Variablen-Matrix und die gemeinsamen Helfer. Wer eine neue
Environment-Variable einführt, ergänzt sie dort — dann decken `1-render.sh` und
`2-nginx-t.sh` sie automatisch mit ab.

## Erwartete Abweichungen in `1-render.sh`

Diese Zeilen dürfen sich vom Referenz-Image unterscheiden, alles andere nicht
(die Liste steht als `ACCEPTED_DIFF` im Skript):

- `error_log` / `access_log` — schreiben zusätzlich nach stdout/stderr
- `fastcgi_pass` — Default von `BEACH_PHP_FPM_HOST` ist `127.0.0.1` statt `localhost`
- `keys_zone` — folgt jetzt `NGINX_CACHE_NAME`, statt hartkodiert zu sein

**Diese Liste gehört zum Umstieg auf `nginx:alpine` und ist gegen 4.13.1
formuliert.** Sobald eine Version released ist, die den Umstieg enthält, zeigt
`REFERENCE_IMAGE` auf genau diese — dann sind die Abweichungen weg und
`ACCEPTED_DIFF` sollte geleert werden. Ab da gilt: *jede* Abweichung ist ein
Fehler, bis jemand sie bewusst hier einträgt. Bleibt die Liste stehen, deckt
der Test diese Zeilen dauerhaft nicht mehr ab.

## Wenn Tests fehlschlagen

`1-render.sh` legt die gerenderten Configs unter `out/reference/` und
`out/candidate/` ab. Direkt vergleichen:

```bash
diff out/reference/cache.conf out/candidate/cache.conf
```

## Stolpersteine

Beim Schreiben dieser Tests haben mehrere Fehlschläge sich als Fehler *im Test*
entpuppt, nicht im Image. Wer hier weiterarbeitet, spart sich damit Zeit:

- **`maxsize 50M` heißt 52.428.800 Bytes.** Eine 52.000.000-Byte-Datei löst die
  Rotation nicht aus, und logrotate meldet das nicht als Fehler.
- **Access-Log-Zeilen tauchen mehrfach auf.** Das error_log enthält die
  Request-Zeile ebenfalls, und Nginx wiederholt fehlgeschlagene Upstreams.
  Deshalb prüft `check_present` auf „mindestens einmal", nicht auf „genau einmal".
- **`NGINX_ACCESS_LOG_ENABLE` wirkt nur im Flow-Mode.** Im Static-Mode gibt der
  Code gar keine `access_log`-Direktive aus. Logging dort zu testen, prüft etwas,
  das es nie gab.
- **Der Entrypoint loggt nach `/dev/stdout`.** Beim Rendern der Config landen
  `[info]`-Zeilen und das Banner im selben Stream — `clean()` in `1-render.sh`
  filtert sie heraus.
- **Ein Fake-FastCGI-Listener bringt nichts.** Nginx wartet dann bis
  `fastcgi_read_timeout` (240s). Für das End-to-End braucht es echtes PHP-FPM.
- **Die Referenz ist im Static-Mode kaputt.** `4.13.1` bricht mit
  `underScoresInHeadersDirective: unbound variable` ab; `1-render.sh` wertet das
  als „nur Kandidat rendert" statt als Fehler. Der Check muss dabei auf den
  *gefilterten* Inhalt gehen — die Ausgabedatei ist trotz Absturz nicht leer,
  weil Banner und `[info]`-Zeilen darin stehen.

## Gegenprobe

Grüne Tests beweisen wenig, solange nicht klar ist, dass sie fehlschlagen
können. Gegen das alte Image finden sie die Bugs, die der Umstieg behoben hat:

```bash
CANDIDATE_IMAGE=harbor.flownative.io/docker/nginx:latest ./2-nginx-t.sh   # 4 Fehler
CANDIDATE_IMAGE=harbor.flownative.io/docker/nginx:latest ./4-php-fpm.sh   # "no live upstreams"
```
