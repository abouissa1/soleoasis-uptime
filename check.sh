#!/usr/bin/env bash
# Checks the public Sole Oasis endpoints from OUTSIDE our own infrastructure.
#
# Why this exists: the other watchdog runs ON the production server and reaches
# the site by going out to the CDN and back in again. That path can break while
# real visitors are fine, and it tells you nothing at all if the server itself
# dies. This runs on a GitHub runner instead — a different network, a different
# continent, and nothing to do with our server.
#
# Exit 0 = everything answered. Exit 1 = at least one endpoint failed every
# attempt, which is what the workflow turns into an alert.
#
# Deliberately retries before crying wolf: a single dropped connection is
# normal on the open internet. Three failures in a row over ~25 s is not.
set -uo pipefail

ATTEMPTS=${ATTEMPTS:-3}
GAP_SECONDS=${GAP_SECONDS:-10}
MAX_TIME=${MAX_TIME:-20}
REPORT=${REPORT:-/dev/stdout}

# name|url|substring the body must contain ("-" = only the status code matters)
TARGETS=${TARGETS:-"website|https://soleoasis.net/|Sole Oasis
staff app|https://app.soleoasis.net/|-
booking|https://soleoasis.net/book|-
api health|https://api.soleoasis.net/api/v1/health|\"ok\""}

failed_any=0
{ echo "| endpoint | result | attempts | time |"; echo "|---|---|---|---|"; } > /tmp/rows.md

while IFS='|' read -r name url needle; do
  [ -z "${name:-}" ] && continue
  ok=0; used=0; detail=""; secs=""
  for i in $(seq 1 "$ATTEMPTS"); do
    used=$i
    body=$(mktemp)
    out=$(curl -sS -o "$body" --max-time "$MAX_TIME" \
          -w '%{http_code} %{time_total}' "$url" 2>/tmp/curlerr) && rc=0 || rc=$?
    code=${out%% *}; secs=${out##* }
    if [ "$rc" -ne 0 ]; then
      detail="no response (curl exit $rc$( [ "$rc" = 28 ] && echo ', timed out'))"
    elif [ "$code" != "200" ]; then
      detail="HTTP $code"
    elif [ "$needle" != "-" ] && ! grep -qF -- "$needle" "$body"; then
      detail="HTTP 200 but the page did not contain $needle"
    else
      ok=1
    fi
    rm -f "$body"
    [ "$ok" = 1 ] && break
    [ "$i" -lt "$ATTEMPTS" ] && sleep "$GAP_SECONDS"
  done

  if [ "$ok" = 1 ]; then
    note=$( [ "$used" -gt 1 ] && echo "ok (recovered on try $used)" || echo "ok" )
    printf '| %s | ✅ %s | %s/%s | %ss |\n' "$name" "$note" "$used" "$ATTEMPTS" "$secs" >> /tmp/rows.md
  else
    failed_any=1
    printf '| %s | ❌ %s | %s/%s failed | — |\n' "$name" "$detail" "$used" "$ATTEMPTS" >> /tmp/rows.md
  fi
done <<< "$TARGETS"

{
  cat /tmp/rows.md
  echo
  echo "Checked from a GitHub runner at $(date -u '+%Y-%m-%d %H:%M:%S') UTC."
  echo "Each endpoint was tried up to ${ATTEMPTS}× with ${GAP_SECONDS}s between tries."
} > "$REPORT"

exit "$failed_any"
