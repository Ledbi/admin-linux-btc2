\## Bilan des critères de réussite



| Critère de l'énoncé | Résultat |

|---|---|

| `helios-collect.service` activé et survit à un `kill -9` | Validé : PID 1074 → 1196 en 5 s |

| `MemoryMax=100663296` sans modifier l'unit d'origine | Validé : réglage dans le drop-in `override.conf` |

| `helios.target` contient `helios-collect.service` | Validé (`list-dependencies`) |

| Bond : deux ports `MII Status: up` et un `Active Slave` | Validé |

| Coupure de l'adaptateur 3 : au plus 2 requêtes perdues | Validé : 1 perte sur 60 |

| `ip route get` : sortie par `bond0.42` depuis l'adresse VLAN, par `enp0s3` sinon | Validé |

| Configuration réseau persistante après `reboot` | Validé |

| Script : code 2 si verrou pris, 3 si source absente | Validé (codes 0, 2 et 3 observés) |

| `list-timers` affiche un NEXT cohérent avec 02:30 | Validé : 02:30:49, puis 02:31:14 |

| Bonus : unit path | Validé : déclenchement à 14:45:18 |



10 critères sur 10 validés.



\## Résultats chiffrés



| Mesure | Avant | Après |

|---|---|---|

| Temps de démarrage total | 1 min 24,5 s | 25,3 s |

| Temps en espace utilisateur | 1 min 6,0 s | 3,9 s |

| Score `systemd-analyze security` | 5.3 MEDIUM | 0.8 SAFE |

| Perte de paquets pendant la bascule du bond | — | 1 sur 60 |



\## Répartition du temps



La préparation de l'environnement (téléchargement, création et installation des VM) a pris une part importante de la séance, à cause des coupures de téléchargement de l'ISO. Une fois les VM prêtes, les trois missions et le bonus ont été réalisés entre 14:06 et 14:45, soit environ 40 minutes, plus la mesure de démarrage commencée à 12:50. La mission 3 a été la plus longue (environ 22 minutes) à cause du test de rattrapage, qui demandait d'éteindre la VM plusieurs minutes.



\## Compétences acquises



\- Créer une unit systemd, la surcharger proprement par un drop-in et mesurer son niveau d'isolation.

\- Analyser une séquence de démarrage et identifier l'unité réellement bloquante.

\- Configurer un bond, un VLAN 802.1Q et du routage par règles avec `nmcli`, et prouver leur fonctionnement par des tests.

\- Écrire un script shell robuste (mode strict, verrou, `trap`, journalisation, codes retour).

\- Choisir entre cron et un timer systemd à partir d'observations concrètes.

\- Créer et piloter des VM en ligne de commande avec `VBoxManage`, et versionner un travail avec Git.

