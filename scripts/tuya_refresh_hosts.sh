#!/bin/bash
# Resolves current IPs for apigw.tuyaus.com and updates /etc/hosts
# Safe to run multiple times

DOMAIN="apigw.tuyaus.com"
HOSTS_FILE="/etc/hosts"
MARKER_START="# tuya-hosts-start"
MARKER_END="# tuya-hosts-end"

# Resolve current IPs
NEW_IPS=$(dig +short "$DOMAIN" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

if [ -z "$NEW_IPS" ]; then
  echo "$(date): tuya_refresh_hosts: could not resolve $DOMAIN, keeping existing entries" >> /tmp/tuya_watchdog.log
  exit 1
fi

# Build replacement block
NEW_BLOCK="$MARKER_START"
while IFS= read -r ip; do
  NEW_BLOCK="$NEW_BLOCK
$ip $DOMAIN"
done <<< "$NEW_IPS"
NEW_BLOCK="$NEW_BLOCK
$MARKER_END"

# Remove old block (between markers or bare apigw lines) and append new block
if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
  # Remove existing marked block
  sudo sed -i "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
else
  # Remove bare lines (legacy format)
  sudo sed -i "/$DOMAIN/d" "$HOSTS_FILE"
fi

echo "$NEW_BLOCK" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "$(date): tuya_refresh_hosts: updated $DOMAIN → $(echo $NEW_IPS | tr '\n' ' ')" >> /tmp/tuya_watchdog.log
