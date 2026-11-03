# TP2 — Gestion avancée des utilisateurs et des groupes

## Mission 2.2 — umask : prédiction avant mesure

Calcul : un fichier part de 666 et un répertoire de 777 ; l'umask retire les bits qu'il contient (4 = r, 2 = w, 1 = x), chiffre par chiffre.

| Cas | umask | Fichier prédit | Répertoire prédit | Fichier observé | Répertoire observé |
|---|---|---|---|---|---|
| 1 (défaut de nadia) | 027 | 640 `rw-r-----` | 750 `rwxr-x---` | 640 `rw-r-----` | 750 `rwxr-x---` |
| 2 | 002 | 664 `rw-rw-r--` | 775 `rwxrwxr-x` | 664 `rw-rw-r--` | 775 `rwxrwxr-x` |
| 3 | 077 | 600 `rw-------` | non testé | 600 `rw-------` | — |

Les trois prédictions sont confirmées. L'umask par défaut de nadia (0027) vient de `UMASK 027` dans `/etc/login.defs`.

### umask par groupe (`/etc/profile.d/helios-umask.sh`)

- nadia (membre de `transport`) : umask 0002 ; `partage.txt` créé dans `transport/` en `-rw-rw-r--`, groupe `transport` (setgid du répertoire), donc modifiable par l'équipe.
- audit-ext (non membre) : umask 0027 conservé.

Le umask est posé dans `/etc/profile.d` et non dans `~/.bashrc`, car `.bashrc` est lu après et l'écraserait.

## Mission 2.3 — setuid / setgid

### Le setuid est ignoré sur un script

Script `faux-setuid.sh` appartenant à root, mode `-rwsr-xr-x` : exécuté par nadia, `id` affiche `uid=5101(nadia)`. Le noyau ignore le bit setuid sur les scripts interprétés (`#!`), car l'intervalle entre la lecture du script et son exécution par l'interpréteur pourrait être exploité.

### Inventaire (16 binaires) et justification de trois d'entre eux

| Binaire | Mode | Pourquoi il est setuid root |
|---|---|---|
| `/usr/bin/passwd` | `-rwsr-xr-x` | Un utilisateur doit pouvoir changer son mot de passe, donc écrire dans `/etc/shadow`, lisible et modifiable seulement par root. Le programme limite lui-même ce que l'utilisateur peut modifier (son propre mot de passe). |
| `/usr/bin/gpasswd` | `-rwsr-xr-x` | Permet à un administrateur de groupe (julien pour `transport`) de modifier `/etc/group` et `/etc/gshadow`, réservés à root. Utilisé à la mission 1.3. |
| `/usr/bin/su` | `-rwsr-xr-x` | Doit vérifier le mot de passe du compte cible (lecture de `/etc/shadow` via PAM), puis changer d'identité, ce qui exige les droits root. |

Cas légitime ajouté : `/usr/local/bin/helios-lastlog` en **setgid** `telemetry` (et non setuid root). Il donne uniquement le droit de lecture du groupe sur `app.log`, l'utilisateur garde son identité, et le chemin et l'environnement sont figés dans le code pour éviter les injections via `PATH` ou `IFS`.

Résultat : `tail` direct refusé à julien (rc=1), lecture via `helios-lastlog` autorisée (rc=0).


## Mission 3 — ACL POSIX

### Ce que chmod g-w modifie sur un fichier porteur d'ACL

Sur un fichier qui a des ACL étendues, les bits « groupe » du mode classique (affichés par ls -l, modifiés par chmod g...) ne représentent plus le groupe propriétaire : ils représentent le masque (mask::).

chmod g-w n'a donc modifié ni group:: ni l'entrée user:tarek:rwx : il a retiré w du masque, passé de rwx à r-x. Le masque limite toutes les entrées nommées et le groupe propriétaire. Les droits réels sont l'intersection de l'entrée et du masque, affichée par getfacl dans les commentaires #effective.

Observé : user:tarek:rwx #effective:r-x, et l'écriture de tarek est refusée (rc=1). Après setfacl -m m::rwx, le masque est rétabli et tarek écrit de nouveau (rc=0).

Piège : un chmod de routine sur un fichier porteur d'ACL peut retirer silencieusement des droits à des utilisateurs nommés. Il faut vérifier avec getfacl et lire les lignes #effective.

### Remarque sur l'ACL par défaut de l'auditeur

setfacl -d -m u:audit-ext:r donne r-- sans x aux sous-répertoires créés ensuite (ex. semaine-41) : audit-ext voit leur contenu mais ne peut pas y entrer. Il aurait fallu u:audit-ext:rX.

### Sauvegarde et transport des ACL

- getfacl -R transport > acl-transport-<date>.txt : sauvegarde texte de toutes les ACL (fichier dans configs/).
- setfacl -R -b : supprime toutes les ACL ; setfacl --restore les remet à l'identique.
- cp -a conserve les ACL, le propriétaire, le groupe et le setgid.
- cp -r perd les ACL, et la copie appartient à root:root sans setgid.
- tar doit recevoir --acls --xattrs pour inclure les ACL dans l'archive.

## Mission 4 — Délégation sudo fine et traçable

### Règle restreinte helios-ops

90-helios-ops : le groupe helios-ops peut piloter uniquement le service Helios (start/stop/restart/status de helios-collect.service et helios.target) et lire ses journaux. visudo -c retourne "analyse réussie". sudo -l -U julien liste restart helios-collect.service mais pas restart sshd.

Traçabilité (log_output, iolog_dir, logfile) : chaque session est enregistrée et rejouable avec sudoreplay. Les refus sont aussi tracés (command not allowed). Les lignes pam_unix montrent "by ledbi(uid=5100)" : on remonte à l'humain réel derrière su - julien.

### Pourquoi une règle laxiste ne protège rien

Règle 99-mauvais-exemple : nadia ALL=(root) NOPASSWD: /usr/bin/vim <fichier>. En lançant sudo vim puis :terminal (ou :!cmd), nadia obtient un shell root (uid=0). Donner le droit de lancer un éditeur en root = donner un accès root complet, car tout éditeur sait exécuter des commandes.

Correction avec sudoedit (91-nadia-edition) : l'éditeur s'exécute avec les droits de nadia sur une copie temporaire. Le même test :terminal affiche uid=5101(nadia) : aucune élévation possible. Règle à retenir : ne jamais déléguer un éditeur via sudo, utiliser sudoedit.

## Mission bonus — Audit croisé : 5 constats

1. Fichier temporaire d'édition abandonné par root dans le projet : /srv/helios/projets/transport/.tournee-nadia.csv.swp (owner root), résidu d'un sudo vim. Remédiation : rm -f /srv/helios/projets/transport/.tournee-nadia.csv.swp (et préférer sudoedit à sudo vim).

2. ACL par défaut de l'auditeur sans droit de traversée : sur semaine-41, audit-ext a r-- sans x, il ne peut pas entrer dans les sous-répertoires. Remédiation : setfacl -d -m u:audit-ext:rX /srv/helios/projets/transport puis setfacl -R -m u:audit-ext:rX /srv/helios/projets/transport.

3. ACL résiduelle trop large : tournee-j2.csv porte encore user:tarek:rwx, posé pour la démonstration du masque, qui n'a plus lieu d'être. Remédiation : setfacl -x u:tarek /srv/helios/projets/transport/tournee-j2.csv.

4. Répertoire world-writable : /srv/helios/depot en 1777. Le sticky bit protège contre la suppression croisée, mais tout le monde peut y écrire. À confirmer comme voulu ; sinon restreindre au groupe : chmod 1770 /srv/helios/depot && chown root:transport /srv/helios/depot.

5. Comptes à surveiller : audit-ext (UID 5103) est un accès externe temporaire avec shell /bin/bash et expiration au 24/11. Vérifier régulièrement qu'il expire bien. Remédiation / contrôle : chage -l audit-ext ; après le mandat, usermod -L -e 1 audit-ext pour verrouiller.

Points positifs relevés : aucun compte sans mot de passe (/etc/shadow), le setgid n'est présent que sur les répertoires de projet attendus.
