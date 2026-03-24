#!/bin/bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3Mjk5OTVhYTYxODQ0YWIzYjA4Mjk2YTliNmM1YzdlYSIsImlhdCI6MTc3NDE1MDkxMCwiZXhwIjoyMDg5NTEwOTEwfQ.wRegYkBhAfRWOQA3Be4v1CwFpIkgMCGeD4LnZ6mB4vQ"
TUYA_ENTRY="01KM9TGW6AQQ79BYM99C39JXHM"
LOG="/tmp/tuya_watchdog.log"

# --- 1. KEEPALIVE (siempre, independiente del DNS) ---
# Consulta el estado de un switch para mantener el MQTT de Tuya activo.
# No usa DNS externo, solo llama a localhost:8123.
curl -s "http://localhost:8123/api/states/switch.salon_interruptor_1" \
  -H "Authorization: Bearer $TOKEN" >/dev/null 2>&1

# --- 2. WATCHDOG Tuya (solo si HA responde) ---
TUYA_STATE=$(curl -s --max-time 5 \
  "http://localhost:8123/api/config/config_entries/entry/$TUYA_ENTRY" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('state',''))" 2>/dev/null)

if [ "$TUYA_STATE" = "setup_error" ] || [ "$TUYA_STATE" = "not_loaded" ] || [ "$TUYA_STATE" = "failed_unload" ]; then
  curl -s -X POST "http://localhost:8123/api/config/config_entries/$TUYA_ENTRY/reload" \
    -H "Authorization: Bearer $TOKEN" >/dev/null
  echo "$(date): Tuya recargada (estado era: $TUYA_STATE)" >> "$LOG"
fi
