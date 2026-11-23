#!/usr/bin/env bash
# Test de fumée en local : même logique que pipelines/templates/smoke-test.yml.
# Usage : ./scripts/smoke-test.sh http://localhost:5080 [version-attendue] [environnement-attendu]
set -euo pipefail
url="${1:-http://localhost:5080}"
version_attendue="${2:-}"
environnement_attendu="${3:-}"

for i in $(seq 1 20); do
  curl -fs "$url/sante" > /dev/null && break   # silencieux pendant le démarrage
  [ "$i" -eq 20 ] && { echo "ECHEC : $url/sante ne répond pas"; exit 1; }
  sleep 1
done

infos=$(curl -fsS "$url/version")
echo "/version : $infos"
version=$(echo "$infos" | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])")
environnement=$(echo "$infos" | python3 -c "import json,sys; print(json.load(sys.stdin)['environnement'])")

if [ -n "$version_attendue" ] && [ "$version" != "$version_attendue" ]; then
  echo "ECHEC : version $version, attendue $version_attendue"; exit 1
fi
if [ -n "$environnement_attendu" ] && [ "$environnement" != "$environnement_attendu" ]; then
  echo "ECHEC : environnement $environnement, attendu $environnement_attendu"; exit 1
fi
echo "OK : version $version en $environnement"
