
## Mission bonus

### Immuabilité d'auditd
Ajout de `-e 2` en fin de 90-helios.rules : auditctl -s affiche enabled 2, et auditctl -D est refusé (Operation not permitted). Les règles sont verrouillées jusqu'au reboot : un attaquant ayant obtenu root ne peut plus effacer la configuration d'audit ni couvrir ses traces. Retour à -e 1 pour la suite.

### Revue cryptographique
ssh -Q cipher / ssh -Q kex listent TOUT ce qu'OpenSSH supporte (dont 3des-cbc, diffie-hellman-group1-sha1, obsolètes). La config effective (sshd -T) ne retient que : chacha20-poly1305/aes256-gcm/aes256-ctr pour les ciphers, curve25519-sha256/dh-group16-sha512 pour les KEX, hmac-sha2-512/256-etm pour les MACs. L'écart entre "supporté" et "autorisé" est la marge de durcissement.

### Pourquoi AuthenticationMethods publickey > PasswordAuthentication no seul
PasswordAuthentication no désactive une méthode (le mot de passe), mais d'autres méthodes restent potentiellement actives (clavier-interactif, GSSAPI, etc.) selon la config et les modules PAM. Un oubli ou un drop-in ultérieur peut rouvrir une voie par mot de passe.
AuthenticationMethods publickey fonctionne en liste blanche : il impose la clé publique comme SEULE méthode acceptée, et rejette tout le reste par défaut. C'est une approche "deny all sauf X" (plus sûre) au lieu de "allow all sauf X" (fragile). Les deux combinées donnent une défense en profondeur.
