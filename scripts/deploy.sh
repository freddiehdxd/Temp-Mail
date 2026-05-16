#!/usr/bin/env bash
# Blue-green deploy for the Tempmail Phoenix app.
#
# Topology:
#   - Two systemd units, tempmail-blue (port 4001) and tempmail-green (port 4002)
#   - Both run /var/www/tempmail/_build/prod/rel/tempmail/bin/server from the same release.
#   - Active color is tracked in .deploy/active_color.
#   - nginx upstream lives in /etc/nginx/conf.d/tempmail-upstream.conf (single server line).
#   - Health endpoint: /healthz (DB-less plug in lib/tempmail_web/endpoint.ex).
#   - Migrations run on release boot via rel/overlays/bin/server.
#
# Flow:
#   1. Build release (mix deps.get -> assets.deploy -> release --overwrite)
#   2. Start the idle color (systemctl restart)
#   3. Poll /healthz on the idle port up to 60s; abort and leave old color serving on failure
#   4. Rewrite upstream include, nginx -t (rollback on failure), nginx -s reload
#   5. systemctl stop the old color, flip .deploy/active_color
set -Eeuo pipefail

ROOT=/var/www/tempmail
ACTIVE_FILE=$ROOT/.deploy/active_color
UPSTREAM_FILE=/etc/nginx/conf.d/tempmail-upstream.conf
BLUE_PORT=4001
GREEN_PORT=4002
HEALTH_TIMEOUT=60
DRAIN_SECONDS=30

log()  { printf '\033[1;34m[deploy %(%H:%M:%S)T]\033[0m %s\n' -1 "$*"; }
fail() { printf '\033[1;31m[deploy ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "must run as root"
[[ -f $ACTIVE_FILE ]] || fail "$ACTIVE_FILE missing"

cd "$ROOT"
ACTIVE=$(<"$ACTIVE_FILE")
case "$ACTIVE" in
  blue)  IDLE=green; IDLE_PORT=$GREEN_PORT; ACTIVE_PORT=$BLUE_PORT  ;;
  green) IDLE=blue;  IDLE_PORT=$BLUE_PORT;  ACTIVE_PORT=$GREEN_PORT ;;
  *) fail "unknown active color: $ACTIVE" ;;
esac

log "active=$ACTIVE (:$ACTIVE_PORT)  ->  deploying to $IDLE (:$IDLE_PORT)"

# Load .env so mix sees DATABASE_URL etc.
set -a; . "$ROOT/.env"; set +a
export MIX_ENV=prod

log "git rev: $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD)"

log "mix deps.get"
/usr/local/bin/mix deps.get >/dev/null

if [[ -f assets/package.json ]]; then
  log "npm install (assets)"
  (cd assets && npm install --silent --no-audit --no-fund)
fi

log "mix assets.deploy"
/usr/local/bin/mix assets.deploy >/dev/null

log "mix release --overwrite"
/usr/local/bin/mix release --overwrite >/dev/null

log "starting tempmail-$IDLE.service (migrations run on boot)"
systemctl restart "tempmail-$IDLE.service"

log "polling http://127.0.0.1:$IDLE_PORT/healthz (up to ${HEALTH_TIMEOUT}s)"
HEALTHY=0
for ((i=1; i<=HEALTH_TIMEOUT; i++)); do
  CODE=$(curl -sS -o /dev/null -m 1 -w "%{http_code}" "http://127.0.0.1:$IDLE_PORT/healthz" 2>/dev/null || echo 000)
  if [[ $CODE == "200" ]]; then HEALTHY=1; log "$IDLE healthy after ${i}s"; break; fi
  sleep 1
done
if [[ $HEALTHY -ne 1 ]]; then
  log "$IDLE failed health-check; stopping it and leaving $ACTIVE serving traffic"
  systemctl stop "tempmail-$IDLE.service" || true
  fail "deploy aborted"
fi

log "rewriting nginx upstream: :$ACTIVE_PORT -> :$IDLE_PORT"
cat > "$UPSTREAM_FILE" <<EOF
upstream tempmail_upstream {
    server 127.0.0.1:$IDLE_PORT;
    keepalive 64;
}
EOF
if ! nginx -t >/dev/null 2>&1; then
  log "nginx config test failed; reverting upstream"
  cat > "$UPSTREAM_FILE" <<EOF
upstream tempmail_upstream {
    server 127.0.0.1:$ACTIVE_PORT;
    keepalive 64;
}
EOF
  systemctl stop "tempmail-$IDLE.service" || true
  fail "deploy aborted"
fi
nginx -s reload

echo "$IDLE" > "$ACTIVE_FILE"
log "active color is now $IDLE"

log "draining $ACTIVE for ${DRAIN_SECONDS}s"
sleep "$DRAIN_SECONDS"

log "stopping tempmail-$ACTIVE.service"
systemctl stop "tempmail-$ACTIVE.service"

log "deploy complete: $IDLE serving on :$IDLE_PORT"
