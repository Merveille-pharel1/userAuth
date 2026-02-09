#!/usr/bin/env bash
set -euo pipefail
# Script de démarrage : génère un SESSION_SECRET persistant dans .env si absent,
# puis lance le serveur.

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Génération d'un SESSION_SECRET et écriture dans .env"
  SECRET=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
  cat > .env <<EOF
SESSION_SECRET=${SECRET}
EOF
fi

# Exporter les variables du .env (simple)
set -a
# shellcheck disable=SC2046
. ./.env
set +a

# Lancer le serveur
ruby serveur/server.rb
