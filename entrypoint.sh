#!/bin/sh
# Site Probe runtime: health cover on $PORT; internal event bridge on loopback.
set -eu
: "${UUID:?UUID env required}"
: "${WSPATH:?WSPATH env required}"
PORT="${PORT:-8080}"
case "$WSPATH" in /*) ;; *) WSPATH="/$WSPATH" ;; esac
export WSPATH PORT
BIN="${APP_BIN:-/usr/local/bin/svc}"
export XRAY_LOCATION_ASSET="${XRAY_LOCATION_ASSET:-/usr/local/share/svc}"
BACKEND_PORT=8081
CFG=/tmp/svc.json
cat > "$CFG" <<JSON
{
  "log": { "loglevel": "${LOGLEVEL:-warning}" },
  "dns": { "servers": ["https+local://1.1.1.1/dns-query", "https+local://8.8.8.8/dns-query"], "queryStrategy": "UseIPv4" },
  "inbounds": [{
    "listen": "127.0.0.1", "port": ${BACKEND_PORT}, "protocol": "vless",
    "settings": { "clients": [ { "id": "${UUID}" } ], "decryption": "none" },
    "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "${WSPATH}" } },
    "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
  }],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct", "settings": { "domainStrategy": "UseIPv4" } },
    { "protocol": "blackhole", "tag": "block" }
  ],
  "routing": { "domainStrategy": "IPIfNonMatch", "rules": [
    { "type": "field", "domain": ["geosite:private"], "outboundTag": "block" },
    { "type": "field", "ip": ["geoip:private"], "outboundTag": "block" },
    { "type": "field", "protocol": ["bittorrent"], "outboundTag": "block" }
  ]}
}
JSON
"$BIN" run -c "$CFG" &
BP=$!
PORT="$PORT" WSPATH="$WSPATH" BACKEND_PORT="$BACKEND_PORT" COVER_ROOT="/opt/app/public" \
  python3 /opt/app/cover.py &
SP=$!
trap 'kill $BP $SP 2>/dev/null; wait' TERM INT
echo "site-probe listening on ${PORT}"
i=0
while [ $i -lt 40 ]; do
  if wget -q -O - "http://127.0.0.1:${PORT}/healthz" 2>/dev/null | grep -q ok; then
    break
  fi
  i=$((i+1)); sleep 0.25
done
while kill -0 "$SP" 2>/dev/null; do
  if ! kill -0 "$BP" 2>/dev/null; then
    "$BIN" run -c "$CFG" &
    BP=$!
  fi
  sleep 2
done
kill "$BP" 2>/dev/null || true
wait || true
exit 1
