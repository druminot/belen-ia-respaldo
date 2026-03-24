#!/bin/bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3Mjk5OTVhYTYxODQ0YWIzYjA4Mjk2YTliNmM1YzdlYSIsImlhdCI6MTc3NDE1MDkxMCwiZXhwIjoyMDg5NTEwOTEwfQ.wRegYkBhAfRWOQA3Be4v1CwFpIkgMCGeD4LnZ6mB4vQ"
TUYA_ENTRY="01KM9TGW6AQQ79BYM99C39JXHM"
LOG="/tmp/tuya_watchdog.log"

# --- 1. KEEPALIVE: refresca TODOS los switches activos ---
# Esto mantiene la sesión MQTT con Tuya cloud viva
ENTITIES='["switch.salon_interruptor_1","switch.salon_interruptor_2","switch.salon_interruptor_3","switch.dormitorio_interruptor_1","switch.dormitorio_interruptor_2","switch.dormitorio_interruptor_3","switch.centro_salon_interruptor_1","switch.centro_salon_interruptor_2","switch.centro_salon_interruptor_3","switch.encimera_lavadora_bloqueo_infantil","switch.oficina_interruptor_1","switch.oficina_interruptor_2","switch.oficina_interruptor_3","switch.monitor_mac_enchufe_1"]'
curl -s -X POST "http://localhost:8123/api/services/homeassistant/update_entity" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\": $ENTITIES}" >/dev/null 2>&1

# --- 2. WATCHDOG: recarga Tuya solo si hay error ---
TUYA_STATE=$(curl -s --max-time 5 \
  "http://localhost:8123/api/config/config_entries/entry/$TUYA_ENTRY" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('state',''))" 2>/dev/null)

if [ "$TUYA_STATE" = "setup_error" ] || [ "$TUYA_STATE" = "not_loaded" ] || [ "$TUYA_STATE" = "failed_unload" ]; then
  curl -s -X POST "http://localhost:8123/api/config/config_entries/$TUYA_ENTRY/reload" \
    -H "Authorization: Bearer $TOKEN" >/dev/null
  echo "$(date): Tuya recargada (estado era: $TUYA_STATE)" >> "$LOG"
fi
