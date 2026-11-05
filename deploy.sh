#!/usr/bin/env bash
#
# SSBU League - Deploy auf dem Server. Normalerweise vom Laptop: deploy
#
#   ./deploy.sh            aktuellen Stand bauen und ausrollen
#   ./deploy.sh --status   was läuft gerade?
#   ./deploy.sh --zurueck  auf die vorige Version zurück
#
# Ablauf: Datenbank sichern, Images bauen, Container tauschen, Gesundheit prüfen.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

COMPOSE=(docker compose -f compose-prod.yaml)
BACKUPS_BEHALTEN_TAGE=14

status() { echo "===> $1"; }

[ -f .env ] || { echo "Es fehlt die .env neben deploy.sh (Vorlage: .env.template)." >&2; exit 1; }

sichern() {
  # Beim allerersten Start läuft noch keine Datenbank, die man sichern könnte.
  [ -n "$("${COMPOSE[@]}" ps -q postgres-prod)" ] || return 0
  local ziel="backups/ssbu-$(date +%Y%m%d-%H%M%S).sql.gz"
  umask 077
  mkdir -p backups
  status "Sichere Datenbank nach $ziel"
  "${COMPOSE[@]}" exec -T postgres-prod sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' | gzip > "$ziel.tmp"
  mv "$ziel.tmp" "$ziel"
  find backups -name '*.sql.gz' -mtime +"$BACKUPS_BEHALTEN_TAGE" -delete
}

gesund() {
  for _ in $(seq 1 60); do
    [ "$(curl -s -o /dev/null -m 3 -w '%{http_code}' http://127.0.0.1:8080/)" = 200 ] && return 0
    sleep 2
  done
  return 1
}

ausrollen() {
  sichern
  status "Baue und tausche Container ($(git rev-parse --short HEAD))"
  "${COMPOSE[@]}" up -d --build --remove-orphans
  status "Warte auf die App"
  if ! gesund; then
    "${COMPOSE[@]}" logs --tail=80 webapp
    echo "Die App antwortet nicht. Zurück auf die vorige Version: deploy zurueck" >&2
    exit 1
  fi
  # Alter Build-Cache belegt sonst dauerhaft die Platte.
  docker builder prune -f --filter until=168h > /dev/null
  status "Fertig: $(git rev-parse --short HEAD) läuft."
}

case "${1:-}" in
  "")
    laufend="$(cat .version 2>/dev/null || true)"
    aktuell="$(git rev-parse HEAD)"
    ausrollen
    if [ "$laufend" != "$aktuell" ]; then
      [ -z "$laufend" ] || echo "$laufend" > .version-vorher
      echo "$aktuell" > .version
    fi
    ;;
  --status)
    echo "Version: $(git log -1 --format='%h %ad %s' --date=short)"
    "${COMPOSE[@]}" ps
    ;;
  --zurueck)
    # Ist der letzte Deploy gescheitert, zeigt .version noch auf den guten Stand.
    ziel="$(cat .version 2>/dev/null || true)"
    [ "$ziel" != "$(git rev-parse HEAD)" ] || ziel="$(cat .version-vorher 2>/dev/null || true)"
    [ -n "$ziel" ] || { echo "Es ist keine vorige Version bekannt." >&2; exit 1; }
    git checkout -q --detach "$ziel"
    ausrollen
    echo "$ziel" > .version
    ;;
  *)
    sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
