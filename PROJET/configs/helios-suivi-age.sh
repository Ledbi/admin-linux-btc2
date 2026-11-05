#!/usr/bin/bash
f=/srv/helios/suivi/www/etat.json
echo $(( $(/usr/bin/date +%s) - $(/usr/bin/stat -c %Y "$f") ))
