#!/usr/bin/bash
# helios-suivi-publish.sh - genere etat.json a partir de telemetry.csv
# Codes : 0 succes - 1 erreur interne - 2 instance deja active - 3 prerequis manquant
set -euo pipefail
IFS=$'\n\t'

readonly SRC=/var/lib/helios/telemetry.csv
readonly WWW=/srv/helios/suivi/www
readonly OUT="${WWW}/etat.json"
readonly LOCK="${WWW}/.publish.lock"
readonly TAG=helios-suivi-publish

log() { logger -t "$TAG" -p "daemon.${1}" -- "$2" ; }
die() { log err "$1" ; exit "${2:-1}" ; }

TMP=""
cleanup() { [[ -n "$TMP" && -e "$TMP" ]] && rm -f -- "$TMP" ; return 0 ; }
trap cleanup EXIT
trap 'die "interrompu" 1' INT TERM

# Prerequis (code 3)
[[ -r "$SRC" ]] || die "source illisible : $SRC" 3
[[ -w "$WWW" ]] || die "www non inscriptible" 3

# Verrou (code 2)
exec 9>"$LOCK"
flock -n 9 || { log warning "une autre instance tourne deja" ; exit 2 ; }

log info "demarrage publication"

# Derniere ligne de telemetrie
last="$(tail -n 1 -- "$SRC")"
[[ -n "$last" ]] || die "telemetrie vide" 1

# Format attendu : date,charge,mem_ko
IFS=',' read -r mesure_date charge mem <<< "$last"
[[ -n "$mesure_date" && -n "$charge" && -n "$mem" ]] || die "ligne de telemetrie invalide" 1

nb="$(wc -l < "$SRC")"
hote="$(hostname)"
genere="$(date --iso-8601=seconds)"

# Ecriture atomique : fichier temporaire dans www, puis mv
TMP="$(mktemp "${WWW}/.etat.XXXXXX")"
cat > "$TMP" <<JSON
{
  "genere": "${genere}",
  "hote": "${hote}",
  "derniere_mesure": "${mesure_date}",
  "charge_1min": ${charge},
  "mem_dispo_ko": ${mem},
  "mesures": ${nb}
}
JSON

chmod 0640 "$TMP"
mv -f -- "$TMP" "$OUT"
TMP=""
log info "etat.json publie (${nb} mesures)"
exit 0
