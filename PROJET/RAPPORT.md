# PROJET — Portail de suivi des tournées Helios — RAPPORT

## 1. Tableau de conformité

| Exigence | Commande de preuve | Résultat |
|---|---|---|
| E1 comptes/groupe | `id lea ; chage -l lea ; getent passwd helios-suivi` | lea uid 5104 gid suivi(5003), pas de wheel/ssh-admins ; 90/1/14/7 ; helios-suivi uid 994, nologin, home /srv/helios/suivi — voir preuves/E1.txt |
| E2 setgid + ACL | `ls -ld www ; getfacl ; runuser -u …` | www 2770 root:suivi+ ; zabbix stat OK / ls refusé ; nadia refusée ; fichier de lea en groupe suivi — preuves/E2.txt |
| E3 script publication | `… publish.sh ; echo $? ; json.tool` | codes 0/2/3 OK, JSON valide, écriture atomique — preuves/E3.txt |
| E4 units durcies | `systemctl status/show ; curl ; systemd-analyze security` | HTTP 200, kill -9 → actif < 10s, score 1.5 OK, Mem 128M/CPU 50% — preuves/E4.txt |
| E5 sudo | `visudo -c ; sudo -l -U lea` | 5 commandes autorisées, restart sshd et --vacuum refusés — preuves/E5.txt |
| E6 pare-feu | `firewall-cmd --query-port ; curl/nc depuis srv-edge` | 8080 dans internal seulement, métier 200 / admin échec — preuves/E6.txt |
| E7 non-régression | `sshd -T ; journalctl` | port 2242/root no/password no/ssh-admins ; lea refusée SSH ; journald 3 boots — preuves/E7.txt |
| E8 supervision | `zabbix_get -k helios.suivi.*` | agent.ping 1, http 200, age < 300 ; sysstat actif — preuves/E8.txt |
| E9 sauvegarde/restau | `sha256sum -c ; tar ; getfacl` | archives + empreinte OK, index.html restauré avec ses ACL — preuves/E9.txt |

## 2. Trois justifications

### (a) Durcissement de helios-suivi.service
Score systemd-analyze security : 1.5 OK (seuil demandé ≤ 4.0). Le serveur web n'écrit nulle part : ProtectSystem=strict sans ReadWritePaths, plus NoNewPrivileges, PrivateTmp, SystemCallFilter=@system-service, CapabilityBoundingSet vide, MemoryDenyWriteExecute. Aucune directive n'a dû être retirée pour ce service : le portail répond toujours 200. En revanche, le service de publication (helios-suivi-publish) a eu besoin de ReadWritePaths=/srv/helios/suivi/www pour écrire etat.json : sans lui, ProtectSystem=strict bloquait l'écriture.

### (b) Pourquoi --x et pas r-x pour zabbix sur www
zabbix doit seulement lire les métadonnées d'un fichier au nom connu (stat www/etat.json), pas lister www. Le droit x sur un répertoire autorise la traversée (atteindre un fichier dont on connaît le nom) ; le droit r autorise le listage (ls). On donne donc u:zabbix:--x : zabbix peut faire stat etat.json mais pas ls www. Observé sans cette entrée : la sonde helios.suivi.age échoue (erreur stat / ZBX_NOTSUPPORTED). Avec --x : age renvoie un nombre, ls reste refusé (rc 2). Moindre privilège respecté.

### (c) Risque d'un joker * dans une règle sudo journalctl
Un joker derrière journalctl (ex. journalctl -u X *) laisserait passer des options destructrices comme --vacuum-time=1s ou --vacuum-size=1K, qui effacent les journaux — un exploitant pourrait détruire les preuves. Notre règle fige les commandes exactes (journalctl -u helios-suivi.service -n 100), sans argument libre. Vérifié : sudo -l -U lea /usr/bin/journalctl --vacuum-time=1s ne liste rien (refusé).

## 3. Test de restauration (E9.5)
(a) Extraction de la dernière archive dans /tmp/restore-test : les getfacl de www en production et dans l'archive sont identiques (entrées helios-suivi, zabbix:--x, et default: toutes présentes).
(b) Incident simulé : rm index.html, puis restauration de ce seul fichier depuis l'archive (tar -C / chemin-relatif). index.html retrouve propriétaire lea, groupe suivi, ses ACL et son contenu, sans toucher au reste de www.
Temps passé : environ 5 minutes. Détail dans preuves/E9.txt.

## 4. Mesure sous charge
Le service a consommé 4,28 s de CPU (CPUUsageNSec 14,50 → 18,79 s) pour traiter 2000 requêtes en 35,3 s, soit ~12 % d'un cœur. Le quota CPUQuota=50% n'a donc PAS joué : la charge est restée bien en dessous du plafond (il sert de garde-fou en cas d'emballement). Mémoire stable à ~10 Mo (quota 128 Mo). sar pendant la charge : %idle ~41%, %system ~42%, %user ~16%.

## 5. Limites connues
- Le serveur HTTP Python (http.server) est mono-thread : il traite les requêtes en série, ce qui explique les 35 s pour 2000 requêtes. Pour la production réelle, un vrai serveur (nginx) serait préférable, mais le projet impose http.server.
- Le bonus E10 (script d'audit) et le RUNBOOK sont traités séparément.
- Avec une journée de plus : ajouter le serveur Zabbix complet (frontend + déclencheurs, bonus E8) pour une supervision visuelle et des alertes.
