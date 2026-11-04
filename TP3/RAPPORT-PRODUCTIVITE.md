\# Rapport de productivité — TP3



\## Déroulé



| Étape | Mission |

|---|---|

| Mission 1 | Pare-feu firewalld : zones par interface, règles riches, ipset, limitation, tests nmap/nc |

| Mission 2 | Durcissement sshd : clé seule, port 2242, AllowGroups, crypto, SELinux, 7 tests |

| Mission 3 | journald persistant, requêtes d'investigation, auditd, script de détection + timer, blocage auto |

| Bonus | Immuabilité auditd, rapports aureport, revue crypto |



\## Difficultés rencontrées et solutions



| Difficulté | Cause | Solution |

|---|---|---|

| Commandes lancées sur srv-edge au lieu de srv-core | Deux VM en parallèle, confusion d'onglet | Vérifier le nom dans l'invite (\[root@srv-core] vs \[srv-edge]) |

| Connexion par clé refusée après durcissement | Clé privée de ledbi absente sur srv-edge | Régénérer la clé sur srv-edge, copier la clé publique via la session root restée ouverte |

| sshd : Bind to port 2242 Permission denied | Port non autorisé par SELinux | semanage port -a -t ssh\_port\_t -p tcp 2242 |

| Script ne bloque pas l'IP | Exactement 5 échecs, condition stricte > 5 | Relancer l'attaque pour dépasser le seuil |

| Not Authorized sur firewall-cmd | Bloc lancé sur srv-edge en simple utilisateur | Relancer sur srv-core en root |

| Blocs collés tronqués (heredoc) | Collage trop long d'un coup | Coller en morceaux, Ctrl+C si invite « > » |



\## Points de sécurité appliqués



\- Session root sur la console VirtualBox gardée ouverte en permanence pendant les modifs SSH/firewall (filet de sécurité).

\- Snapshots successifs : 03-firewall-ok, 04-ssh-ok, pour pouvoir revenir en arrière.

\- Test de chaque modification depuis une seconde connexion avant de valider.



\## Compétences acquises



\- Segmenter un pare-feu firewalld par zones selon un plan d'adressage, écrire des règles riches, vérifier le nftables généré.

\- Durcir sshd (clé seule, restriction par groupe, changement de port) sans se couper l'accès, et gérer les conséquences SELinux/pare-feu.

\- Rendre journald persistant et mener des requêtes d'investigation.

\- Instrumenter auditd sur des fichiers sensibles et exploiter ausearch/aureport.

\- Automatiser la détection d'attaques par force brute et le blocage via ipset.



\## Outils utilisés



firewalld, nftables, nmcli, nmap, nc, sshd, semanage (SELinux), update-crypto-policies, journald, auditd, ausearch/aureport, ipset, systemd timers, Git/GitHub.

