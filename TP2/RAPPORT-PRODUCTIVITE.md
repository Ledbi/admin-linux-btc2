\# Rapport de productivité — TP2



\## Déroulé (d'après les horaires des journaux)



| Heure | Étape |

|---|---|

| 11:05 – 11:16 | Mission 1 : politique (login.defs, pwquality, faillock), comptes et groupes, tests |

| 11:20 – 11:27 | Mission 2 : setgid, sticky, umask, setuid, binaire helios-lastlog |

| 11:30 – 11:33 | Mission 3 : ACL nominatives, ACL par défaut, masque, sauvegarde |

| 11:37 – 12:11 | Mission 4 : délégation sudo, traçabilité, évasion de shell, sudoedit |

| vers 12:15 | Mission bonus : audit croisé |



\## Difficultés rencontrées et solutions



| Difficulté | Cause | Solution |

|---|---|---|

| authselect « Aucune configuration détectée » | Fichiers PAM non gérés par authselect | authselect select sssd with-faillock --force --backup |

| Commandes exécutées en tant que julien au lieu de root | su - julien lancé dans le mauvais onglet | Vérifier l'invite ($ = utilisateur, # = root) avant de taper |

| passwd : « erreur de jeton d'authentification » | Mot de passe actuel mal tapé (AZERTY : Maj pour chiffres) | Retaper lentement, reset faillock si nécessaire |

| sudo : « un terminal est requis » | su - user -c '...' n'ouvre pas de vrai terminal | Se connecter réellement avec su - user puis taper la commande |

| Collage d'un bloc coupé (invite « > ») | Bloc trop long collé en une fois | Ctrl + C puis coller en plus petits morceaux |

| vim/tar/gcc introuvables | Rocky Minimal ne les inclut pas | dnf install vim-enhanced / tar / gcc |

| Évasion de shell impossible à capturer au clavier | Touches ! et / difficiles en AZERTY | Utiliser :terminal dans vim au lieu de :!cmd |



\## Compétences acquises



\- Régler une politique d'authentification (durée de vie, qualité, verrouillage) avant de créer les comptes.

\- Utiliser setuid, setgid et sticky bit, et comprendre pourquoi le setuid est ignoré sur un script.

\- Prédire et expliquer le mode d'un fichier à partir de l'umask.

\- Poser, interroger, sauvegarder et transporter des ACL POSIX, y compris les ACL par défaut et le masque effectif.

\- Rédiger une délégation sudo restreinte et tracée, et comprendre pourquoi déléguer un éditeur revient à donner root.



\## Outils utilisés



Rocky Linux 9, nmcli déjà vu au TP1, authselect, pam\_pwquality, pam\_faillock, setfacl/getfacl, visudo, sudoedit, sudoreplay, gcc, SSH, Git/GitHub.

