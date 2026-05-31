#!/usr/bin/env bash
#
# Triggert einen Redeploy auf dem Produktions-Server.
# Ablauf:  git commit + git push  ->  npm run release
#
# Es wird NICHTS lokal gebaut: der Server zieht sich den Code selbst von GitHub
# und führt dort ./deploy.sh aus (mvn package + docker-compose up --build).
#
set -euo pipefail

SERVER="root@173.212.222.16"
APP_DIR="/home/ssbu_league"
BRANCH="master"

# ins Repo-Root wechseln (egal von wo das Script aufgerufen wird)
cd "$(dirname "$0")/.."

# --- Sicherheitsnetz: nur deployen, was committet UND gepusht ist -------------
if [[ -n "$(git status --porcelain)" ]]; then
  echo "✗ Es gibt uncommittete Änderungen. Erst committen & pushen, dann release." >&2
  exit 1
fi

git fetch -q origin "$BRANCH"
if [[ -n "$(git log "origin/${BRANCH}..${BRANCH}" --oneline 2>/dev/null)" ]]; then
  echo "✗ Lokale Commits sind noch nicht gepusht. Erst 'git push origin ${BRANCH}'." >&2
  exit 1
fi

# --- Redeploy auslösen ---------------------------------------------------------
# Der vorgelagerte 'git pull' stellt sicher, dass die AKTUELLE deploy.sh auf dem
# Server liegt, BEVOR sie ausgeführt wird (sonst läuft evtl. eine alte Version).
echo "===> Löse Redeploy auf ${SERVER} aus ..."
ssh "$SERVER" "set -e; cd '${APP_DIR}' \
  && git fetch origin '${BRANCH}' \
  && git checkout '${BRANCH}' \
  && git pull --ff-only origin '${BRANCH}' \
  && ./deploy.sh"

echo "===> Release abgeschlossen."
