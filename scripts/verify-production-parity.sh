#!/usr/bin/env bash
set -euo pipefail

projekt_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$projekt_root"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Fehlendes Werkzeug: $1" >&2
    exit 1
  fi
}

require_command git
require_command node
require_command npm
require_command docker

echo "[1/5] Arbeitsbaum und Syntax prüfen"
git diff --check
node --check server.js
node --check worker.js

echo "[2/5] Backend-Vertragstests ausführen"
npm test

echo "[3/5] Compose-Konfiguration ohne Secret-Ausgabe validieren"
TSCHLUESSLI_ENV_FILE=.env.example \
TSCHLUESSLI_MYSQL_CA_FILE=/tmp/tschluessli-release-ca-placeholder \
TSCHLUESSLI_IMAGE_REF=tschluessli-api:release-verification \
docker compose -f compose.yml config --quiet

echo "[4/5] Produktionsimage lokal bauen"
docker build --pull=false -t tschluessli-api:release-verification .

echo "[5/5] Image-Sicherheitsmerkmale prüfen"
image_user="$(docker image inspect tschluessli-api:release-verification --format '{{.Config.User}}')"
if [[ "$image_user" != "node" ]]; then
  echo "Release-Image läuft nicht als Benutzer node (gefunden: ${image_user:-root})." >&2
  exit 1
fi

echo "Backend-Releaseprüfung erfolgreich."
echo "Der separate iOS-Gerätebuild und der End-to-End-Test auf DEV bleiben verpflichtende Freigabeschritte."
