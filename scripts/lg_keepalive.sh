#!/bin/bash
# Keepalive TCP para LG webOS TV
# Mantiene el chip WiFi del TV activo enviando una conexión TCP al puerto 3000 (WebSocket webOS)
LG_IP="192.168.1.120"
LOG="/tmp/lg_keepalive.log"

# Solo actúa si el TV está apagado (ping falla) - cuando está encendido no necesita keepalive
if ! ping -c 1 -W 2 "$LG_IP" >/dev/null 2>&1; then
  # TV en standby: enviar conexión TCP al puerto 3000 para mantener el chip WiFi vivo
  timeout 3 bash -c "echo '' > /dev/tcp/$LG_IP/3000" 2>/dev/null
  EXIT=$?
  if [ $EXIT -eq 0 ]; then
    : # Conexión exitosa, chip WiFi vivo
  else
    echo "$(date): TV en standby, chip WiFi no responde (exit=$EXIT)" >> "$LOG"
  fi
fi
