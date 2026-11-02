# TP1 — Configuration avancée du système Linux

Environnement : srv-core et srv-edge, Rocky Linux 9.8 sous VirtualBox.

## 1. Services, processus et démarrage

### Temps de démarrage

| | Avant | Après |
|---|---|---|
| Total | 1 min 24,455 s | 25,267 s |
| Noyau | 2,576 s | 4,181 s |
| initrd | 15,849 s | 17,214 s |
| Espace utilisateur | 1 min 6,028 s | 3,871 s |

Unités désactivées :

- `NetworkManager-wait-online.service` (masquée) : 1 min 0 s dans `systemd-analyze blame`, soit son délai maximal. Elle attendait que toutes les interfaces soient configurées, alors que les connexions `enp0s9` et `enp0s10` créées par l'installeur tentaient sans succès d'obtenir une adresse en DHCP sur `helios-lan`, où aucun serveur DHCP ne répond. Aucun service de ce serveur n'a besoin d'attendre un réseau entièrement configuré.
- `firewalld` (désactivé) : temporairement, il sera réactivé au TP3.

Gain : environ 59 s. Le temps restant (initrd, dont `dracut-initqueue` 12,5 s) correspond à la détection matérielle, avant que systemd prenne la main.

### Service helios-collect

- Redémarrage automatique : après `kill -9`, le PID passe de 1074 à 1196 en environ 5 s (`Restart=on-failure`, `RestartSec=5s`).
- Drop-in `override.conf` (unit d'origine non modifiée) : `MemoryMax=100663296` (96 Mo), `CPUQuotaPerSecUSec=200ms` (20 %), `Nice=5`, intervalle ramené à 5 s.
- Score `systemd-analyze security` : **5.3 MEDIUM** avant, **0.8 SAFE** après. Directives ajoutées : `PrivateNetwork=yes` (le collecteur ne lit que `/proc` et n'ouvre aucune connexion), `PrivateDevices=yes`, `ProtectKernelModules/Logs=yes`, `ProtectClock=yes`, `ProtectHostname=yes`, `ProtectProc=invisible`, `RestrictNamespaces=yes`, `RestrictRealtime=yes`, `LockPersonality=yes`, `MemoryDenyWriteExecute=yes`, `SystemCallFilter=@system-service`, `SystemCallArchitectures=native`, `RestrictAddressFamilies=AF_UNIX`, `UMask=0027`.
- cgroup : 2 processus (le script et son `sleep`), environ 824 Ko de mémoire.

### Target métier

`systemctl list-dependencies helios.target` affiche `helios-collect.service`. Après `systemctl stop helios.target`, le collecteur reste `active` : `add-wants` crée une dépendance `Wants=`, qui ne propage pas l'arrêt. Pour cela, il faudrait `PartOf=helios.target` dans le service.

### Priorités

`sha256sum` lancé en `nice 19` (PRI 0), puis `renice 5` (PRI 14) : root peut augmenter la priorité, un utilisateur normal non. `ionice -c 2 -n 7` = best-effort, niveau le plus bas. `chrt` : `SCHED_OTHER`.

## 2. Réseau

- Bond `active-backup` (`miimon=100`, primaire `enp0s9`) : deux ports `MII Status: up`.
- Bascule : coupure de l'adaptateur 3 à 14:15:43, `enp0s10` devient active dans la même seconde ; retour sur `enp0s9` à 14:16:19 (`primary_reselect always`). Ping continu : 60 transmis, 59 reçus (1 perte).
- VLAN 42 : `bond0.42` (10.42.42.10) ↔ `enp0s9.42` sur srv-edge (10.42.42.11). La capture tcpdump montre des trames `ethertype 802.1Q (0x8100)` avec l'étiquette `vlan 42`.
- Routage par règles : règle `100: from 10.42.42.10 lookup transport`, évaluée avant `main` (32766). `ip route get 8.8.8.8 from 10.42.42.10` sort `via 10.42.42.11 dev bond0.42 table transport` ; `ip route get 8.8.8.8` sort `via 10.0.2.2 dev enp0s3`.
- Persistance : après `systemctl reboot`, le bond, le VLAN, la règle et les routes sont identiques.
- Le mode 802.3ad (LACP) n'est pas réalisable sous VirtualBox, qui n'émule pas de commutateur LACP.

## 3. Automatisation

### Codes retour de helios-archive.sh

| Test | Code | Journal |
|---|---|---|
| Exécution normale | 0 | archive créée (161 lignes), `fin d execution rc=0` |
| Verrou déjà pris | 2 | « une autre instance tourne deja » |
| Source absente | 3 | « source illisible : /var/lib/helios/telemetry.csv » |

La ligne `fin d execution rc=X` apparaît dans tous les cas : `trap cleanup EXIT` s'exécute quelle que soit la sortie.

### Timer : prochaine exécution

`systemctl list-timers` : NEXT à 02:30:49, puis 02:31:14 après redémarrage du timer (`RandomizedDelaySec=120`).

### cron vs systemd timer (observations, planification temporaire toutes les 2 min)

| Critère | systemd timer | cron |
|---|---|---|
| Rattrapage après VM éteinte | Oui (`Persistent=yes`) : exécution à 14:41:04, quelques secondes après le boot, hors planning | Non : rien au boot, première exécution à 14:43:01 ; exécutions manquées perdues sans trace |
| Journalisation et corrélation | `journalctl -u helios-archive.service` : début, sortie du script, fin, code retour (`status=0/SUCCESS`), temps CPU | `journalctl -u crond` : seulement `CMD`/`CMDEND`, sans code retour ni sortie ; corrélation manuelle par l'heure |
| Expression de dépendances | `ConditionPathExists=`, `After=`/`Requires=` possibles | Aucune |
| Limitation de ressources | `Nice=10`, `IOSchedulingClass=idle` (vérifiés par `systemctl show`) ; quotas cgroup possibles | Priorité normale ; `nice`/`ionice` à écrire à la main, sans cgroup |
| Dispersion de la charge | `RandomizedDelaySec=120` : 02:30:49 au lieu de 02:30:00 | Aucune : même seconde sur toutes les machines |
| Prochaine exécution | `systemctl list-timers` : date, temps restant, dernière exécution | Aucun outil natif |

## Bonus : unit path

`helios-inbox.path` (`PathChanged=/srv/helios/inbox`) : `touch /srv/helios/inbox/test.csv` déclenche l'archivage (exécution à 14:45:18). `PathChanged` plutôt que `PathExistsGlob`, car le script ne vide pas l'inbox : la condition resterait vraie et relancerait le service en boucle.
