#!/usr/bin/env bash
# Black-box contract capture: starts the built jar and records status and raw body of each request.
# The script knows nothing about Spring and never changes during migration.
# Usage: capture.sh <jar> <output dir> [extra app args...]
set -euo pipefail

JAR=$1
OUT=$2
shift 2
PORT=${PORT:-18080}
BASE="http://localhost:$PORT"

mkdir -p "$OUT"
rm -f "$OUT"/*.txt

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

probe() {
    curl -s -m 5 -o /dev/null "$BASE/actuator/health"
}

# Another server on this port would answer the probe and the capture would record it
if probe; then
    fail "port $PORT is already in use, set another one with PORT"
fi

java -jar "$JAR" --server.port="$PORT" "$@" >"$OUT.log" 2>&1 &
APP=$!
trap 'kill "$APP" 2>/dev/null || true; wait "$APP" 2>/dev/null || true' EXIT

attempts=0
until probe; do
    kill -0 "$APP" 2>/dev/null || fail "the application exited during startup, see $OUT.log"
    attempts=$((attempts + 1))
    [ "$attempts" -lt 60 ] || fail "no answer on port $PORT after 60 attempts, see $OUT.log"
    sleep 1
done

record() {
    local name=$1 method=$2 path=$3 body=${4:-}
    local args=(-s -m 30 -X "$method" -w '\nHTTP %{http_code}\n' "$BASE$path")
    if [ -n "$body" ]; then
        args+=(-H 'Content-Type: application/json' -d "$body")
    fi
    curl "${args[@]}" >"$OUT/$name.txt"
}

record 01-list-seeded       GET  /api/orders
record 02-get-seeded        GET  /api/orders/1
record 03-create-plain      POST /api/orders '{"sku":"B-200","price":1000.00,"discountPercent":10}'
record 04-create-null-int   POST /api/orders '{"sku":"B-201","price":1000.00,"discountPercent":null}'
record 05-create-no-int     POST /api/orders '{"sku":"B-202","price":1000.00}'
record 06-create-unknown    POST /api/orders '{"sku":"B-203","price":1000.00,"discountPercent":0,"channel":"web"}'
record 07-create-trailing   POST /api/orders '{"sku":"B-204","price":1000.00,"discountPercent":0} {"retry":true}'
record 08-set-status        POST /api/orders/2/status '{"status":"PAID"}'
record 09-health            GET  /actuator/health
