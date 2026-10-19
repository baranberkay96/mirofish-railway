#!/bin/sh
# Hashes the basic-auth password (Caddy needs a bcrypt hash) and starts Caddy.
# The plain password stays in the Railway variable and is passed to caddy on stdin.
set -eu

fail() { printf '[web] ERROR: %s\n' "$*" >&2; exit 1; }

: "${BASIC_AUTH_USERNAME:?BASIC_AUTH_USERNAME must be set}"
: "${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD must be set}"
: "${MIROFISH_BACKEND:?MIROFISH_BACKEND must be set (e.g. mirofish.railway.internal:5001)}"

case "$BASIC_AUTH_USERNAME" in
  *[!A-Za-z0-9._@-]*) fail "BASIC_AUTH_USERNAME may only contain letters, digits and . _ @ -" ;;
esac
if [ "${#BASIC_AUTH_PASSWORD}" -lt 12 ]; then
  fail "BASIC_AUTH_PASSWORD must be at least 12 characters"
fi
case "$BASIC_AUTH_PASSWORD" in
  *"
"*) fail "BASIC_AUTH_PASSWORD must be a single line" ;;
esac

BASIC_AUTH_HASH="$(printf '%s\n' "$BASIC_AUTH_PASSWORD" | caddy hash-password --algorithm bcrypt)"
case "$BASIC_AUTH_HASH" in
  '$2'*) ;;
  *) fail "could not hash BASIC_AUTH_PASSWORD" ;;
esac
export BASIC_AUTH_HASH
unset BASIC_AUTH_PASSWORD

printf '[web] MiroFish UI on :%s, /api -> %s, login user "%s"\n' "${PORT:-8080}" "$MIROFISH_BACKEND" "$BASIC_AUTH_USERNAME"
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
