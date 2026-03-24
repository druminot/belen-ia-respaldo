#!/bin/bash
# Watchdog para LG webOS TV
# Si el TV está encendido (responde a ping) pero HA lo marca unavailable → recarga la integración
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3Mjk5OTVhYTYxODQ0YWIzYjA4Mjk2YTliNmM1YzdlYSIsImlhdCI6MTc3NDE1MDkxMCwiZXhwIjoyMDg5NTEwOTEwfQ.wRegYkBhAfRWOQA3Be4v1CwFpIkgMCGeD4LnZ6mB4vQ"
LG_ENTRY="01KMBTN9AMT4XAA6XGS775YVN6"
LG_IP="192.168.1.120"
LOG="/tmp/lg_watchdog.log"

STATE=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8123/api/states/media_player.lg_webos_tv_43uj6510_sa" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])" 2>/dev/null)

# Si el TV responde a ping pero HA lo ve unavailable → forzar reconexión
if ping -c 1 -W 2 "$LG_IP" >/dev/null 2>&1; then
  if [ "$STATE" = "unavailable" ]; then
    curl -s -X POST "http://localhost:8123/api/services/homeassistant/reload_config_entry" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"entry_id\": \"$LG_ENTRY\"}" >/dev/null
    echo "$(date): TV pingable pero unavailable → integración recargada" >> "$LOG"
  fi
else
  # TV apagado: si HA lo ve unavailable, marcarlo como off (assumed_state)
  if [ "$STATE" = "unavailable" ]; then
    echo "$(date): TV apagado (no responde a ping), estado: $STATE" >> "$LOG"
  fi
fi
