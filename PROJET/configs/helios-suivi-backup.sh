#!/usr/bin/bash
# helios-suivi-backup.sh - archive le service portail avec ACL + empreinte, retention 7.
# Codes : 0 succes - 1 erreur interne - 2 instance deja active - 3 prerequis manquant
set -euo pipefail
IFS=$'\n\t'

readonly DEST=/srv/helios/archives/suivi
readonly RETENTION=7
readonly LOCK=/run/lock/helios-suivi-backup.lock
readonly TAG=helios-suivi-backup

log() { logger -t "$TAG" -p "daemon.${1}" -- "$2" ; }
die() { log err "$1" ; exit "${2:-1}" ; }

TMP=""
cleanup() { [[ -n "$TMP" && -e "$TMP" ]] && rm -f -- "$TMP" ; return 0 ; }
trap cleanup EXIT
trap 'die "interrompu" 1' INT TERM

exec 9>"$LOCK"
flock -n 9 || { log warning "une autre instance tourne deja" ; exit 2 ; }

command -v tar >/dev/null || die "tar absent" 3
[[ -d /srv/helios/suivi ]] || die "repertoire du service absent" 3

install -d -m 0750 -o helios -g helios "$DEST"
stamp="$(date +%Y%m%d-%H%M%S)"
arch="${DEST}/suivi-${stamp}.tar.gz"

log info "demarrage sauvegarde ${stamp}"

# Archive avec ACL et xattrs. On liste les chemins existants seulement.
sources=(/srv/helios/suivi)
for f in /etc/systemd/system/helios-suivi.service \
         /etc/systemd/system/helios-suivi-publish.service \
         /etc/systemd/system/helios-suivi-publish.timer \
         /etc/systemd/system/helios-suivi-backup.service \
         /etc/systemd/system/helios-suivi-backup.timer \
         /etc/sudoers.d/92-helios-suivi \
         /etc/zabbix/zabbix_agent2.d/helios-suivi.conf \
         /usr/local/sbin/helios-suivi-publish.sh \
         /usr/local/sbin/helios-suivi-backup.sh ; do
  [[ -e "$f" ]] && sources+=("$f")
done

TMP="$(mktemp "${DEST}/.suivi-${stamp}.XXXXXX")"
tar --acls --xattrs -czf "$TMP" "${sources[@]}" 2>/dev/null || die "echec tar" 1
mv -f -- "$TMP" "$arch"
TMP=""

# Empreinte
( cd "$DEST" && sha256sum "$(basename "$arch")" > "${arch}.sha256" )
log info "archive ${arch} ($(du -h "$arch" | cut -f1))"

# Retention : ne garder que les RETENTION dernieres (archive + .sha256)
mapfile -t olds < <(ls -1t "${DEST}"/suivi-*.tar.gz 2>/dev/null | tail -n +$((RETENTION+1)))
for old in "${olds[@]:-}" ; do
  [[ -z "$old" ]] && continue
  rm -f -- "$old" "${old}.sha256"
  log info "purge ancienne archive $(basename "$old")"
done

log info "sauvegarde terminee"
exit 0
