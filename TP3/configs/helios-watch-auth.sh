#!/usr/bin/bash
# helios-watch-auth.sh - bloque les IP a >5 echecs d'auth SSH via ipset helios-blacklist.
# Sortie : 0 nominal - 2 verrou deja pris
set -euo pipefail
IFS=$'\n\t'

readonly SEUIL=5
readonly IPSET=helios-blacklist
readonly BLOCKED=/var/lib/helios/blocked.txt
readonly LOCK=/run/lock/helios-watch-auth.lock
readonly TAG=helios-watch-auth
readonly WHITELIST="192.168.56.1"

log() { logger -t "$TAG" -p "daemon.${1}" -- "$2" ; }

exec 9>"$LOCK"
flock -n 9 || { log warning "une autre instance tourne deja" ; exit 2 ; }

install -d -m 0750 /var/lib/helios
touch "$BLOCKED"

# Compter les echecs d'auth SSH des 10 dernieres minutes, par IP source
mapfile -t suspects < <(
  journalctl -u sshd --since '-10min' --no-pager 2>/dev/null \
  | grep -oE 'Invalid user .* from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|Failed .* from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|Connection closed by authenticating user .* [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  | sort | uniq -c \
  | awk -v s="$SEUIL" '$1 > s {print $2}'
)

for ip in "${suspects[@]:-}" ; do
  [[ -z "$ip" ]] && continue
  if grep -qx "$ip" <<< "$WHITELIST" ; then continue ; fi
  if grep -qx "$ip" "$BLOCKED" ; then continue ; fi
  firewall-cmd --ipset="$IPSET" --add-entry="$ip" >/dev/null 2>&1 || true
  echo "$ip" >> "$BLOCKED"
  log warning "IP bloquee : $ip (>$SEUIL echecs)"
done

log info "analyse terminee"
exit 0
