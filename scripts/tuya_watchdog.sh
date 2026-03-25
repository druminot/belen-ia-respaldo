#!/bin/bash
HA_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3Mjk5OTVhYTYxODQ0YWIzYjA4Mjk2YTliNmM1YzdlYSIsImlhdCI6MTc3NDE1MDkxMCwiZXhwIjoyMDg5NTEwOTEwfQ.wRegYkBhAfRWOQA3Be4v1CwFpIkgMCGeD4LnZ6mB4vQ"
HA_URL="http://localhost:8123"
ENTRY_ID="01KM9TGW6AQQ79BYM99C39JXHM"

# Keepalive: refresh entity state to keep MQTT connection active
KEEPALIVE_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.salon_interruptor_3"}' \
  "${HA_URL}/api/services/homeassistant/update_entity" 2>/dev/null)

# If keepalive failed (non-2xx or empty), refresh Tuya IPs first
if [ "$KEEPALIVE_RESULT" != "200" ] && [ "$KEEPALIVE_RESULT" != "201" ]; then
  echo "$(date): keepalive failed (HTTP $KEEPALIVE_RESULT), refreshing hosts" >> /tmp/tuya_watchdog.log
  /home/druminot/.local/bin/tuya_refresh_hosts.sh
fi

# Auto-recovery: reload if Tuya is in error
STATE=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
  "${HA_URL}/api/config/config_entries/entry" | \
  python3 -c "import json,sys; entries=json.load(sys.stdin); tuya=[e for e in entries if e.get('domain')=='tuya']; print(tuya[0].get('state','unknown') if tuya else 'not_found')" 2>/dev/null)

if [ "$STATE" != "loaded" ]; then
  # Refresh hosts before reloading
  /home/druminot/.local/bin/tuya_refresh_hosts.sh
  curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" \
    "${HA_URL}/api/config/config_entries/entry/${ENTRY_ID}/reload" > /dev/null 2>&1
  echo "$(date): Tuya was $STATE, refreshed hosts and reloaded" >> /tmp/tuya_watchdog.log
fi
