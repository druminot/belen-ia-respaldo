# Belén IA — Respaldo Home Assistant

Guía completa para replicar la configuración de Home Assistant en caso de reinstalación o migración.

---

## Estructura del respaldo

```
Belén IA respaldo/
├── scripts/
│   ├── tuya_watchdog.sh      ← Mantiene Tuya activo y reconecta si cae
│   ├── lg_watchdog.sh        ← Reconecta el TV LG si HA lo pierde
│   └── lg_keepalive.sh       ← Keepalive TCP: mantiene chip WiFi del LG activo en standby
├── ha-config/
│   ├── configuration.yaml    ← Config principal de HA (HomeKit Bridge + HomeKit Accessory LG)
│   ├── automations.yaml      ← Control remoto del LG via HomeKit (flechas, OK, etc.)
│   └── scripts.yaml          ← Scripts de botones del TV LG
└── documentacion/
    └── README.md             ← Este archivo
```

---

## Integraciones instaladas

### 1. Tuya (SmartLife)
- **Qué hace:** conecta todos los enchufes e interruptores SmartLife a HA
- **Dispositivos:** 14 switches (Salón, Dormitorio, Oficina, Centro Salón, Monitor Mac, Encimera/Lavadora)
- **Cómo reinstalar:** Configuración → Dispositivos y servicios → Añadir integración → Tuya
- **Cuenta:** requiere cuenta en https://iot.tuya.com (Client ID + Client Secret)

### 2. LG webOS TV
- **TV:** LG 43UJ6510-SA — IP fija `192.168.1.120`
- **MAC (para WoL):** `a0:6f:aa:b9:bd:38`
- **Cómo reinstalar:** Configuración → Añadir integración → LG webOS Smart TV → ingresar IP
- **Nota:** el TV debe estar encendido al hacer el emparejamiento (acepta el popup en pantalla)
- **Activar en el TV:** Quick Start+ (Configuración → General → Quick Start+) para que responda en standby
- **Limitación conocida:** el chip WiFi del LG 2017 se apaga en standby prolongado; el lg_keepalive.sh mitiga esto

### 3. Samsung TV 50" QLED
- **Cómo reinstalar:** Configuración → Añadir integración → Samsung Smart TV

### 4. Apple TV (x2)
- **Ubicación:** Sala
- **Cómo reinstalar:** Configuración → Añadir integración → Apple TV

### 5. HomeKit Bridge (switches)
- **Puerto:** 21063
- **Qué expone:** switches Tuya (sin media players)
- **Dispositivos excluidos** (no aparecen en Casa):
  - switch.dormitorio_interruptor_2
  - switch.oficina_interruptor_1
  - switch.oficina_interruptor_2
  - switch.centro_salon_interruptor_1
  - switch.centro_salon_interruptor_2
  - switch.salon_interruptor_1
  - switch.salon_interruptor_2
- **Vincular con iPhone:** app Casa → + → Agregar accesorio → escanear QR desde HA

### 6. HomeKit Accessory — LG TV (modo dedicado)
- **Puerto:** 21064
- **Modo:** `accessory` (conexión directa iPhone ↔ LG, más estable que bridge para TVs)
- **Qué expone:** media_player.lg_webos_tv_43uj6510_sa
- **Vincular:** app Casa → + → Agregar accesorio → ingresar código PIN desde HA

### 7. Wake-on-LAN
- Habilitado en `configuration.yaml` para intentar encender el LG desde HA/Siri
- **Limitación:** WoL sobre WiFi no funciona de forma confiable en el LG 2017 cuando el chip entra en deep sleep. Solución alternativa: HDMI-CEC con Apple TV o Broadlink IR

---

## Scripts de automatización (ha-config/)

### automations.yaml
8 automatizaciones para el control remoto del LG via HomeKit:
- Flechas ↑↓←→ → UP/DOWN/LEFT/RIGHT
- Botón central (select) → ENTER
- Atrás (back) → BACK
- Salir (exit) → EXIT
- Info (information) → HOME (pantalla principal del LG)

**Evento utilizado:** `homekit_tv_remote_key_pressed` (con "d" al final — nombre exacto en HA 2026.x)

### scripts.yaml
7 scripts de botones (redundancia manual): LG Arriba, Abajo, Izquierda, Derecha, OK, Atrás, Home.

---

## Watchdogs (scripts/)

### tuya_watchdog.sh
**Propósito:** mantener la integración Tuya conectada permanentemente.

**Dos funciones:**
1. **Keepalive real** — llama a `homeassistant.update_entity` en los 14 switches cada minuto para mantener el MQTT de Tuya activo (no usa caché)
2. **Auto-recovery** — si Tuya cae en `setup_error`, la recarga automáticamente

**Cómo instalar:**
```bash
cp tuya_watchdog.sh ~/.local/bin/tuya_watchdog.sh
chmod +x ~/.local/bin/tuya_watchdog.sh
# Agregar al crontab:
crontab -e
# Agregar línea: */1 * * * * /home/druminot/.local/bin/tuya_watchdog.sh
```

**Variables a actualizar si se reinstala HA:**
- `TOKEN` → nuevo token de larga duración (HA → Perfil → Tokens de acceso)
- `TUYA_ENTRY` → nuevo entry_id de Tuya (visible en la URL al abrir la integración en HA)

### lg_watchdog.sh
**Propósito:** reconectar el TV LG cuando HA pierde la conexión WebOS.

**Lógica:**
- Si el TV responde a ping pero HA lo ve `unavailable` → recarga la integración webOS
- Si el TV no responde a ping → está apagado, no hace nada

**Variables a actualizar:**
- `TOKEN` → mismo token de larga duración
- `LG_ENTRY` → entry_id de la integración LG webOS en HA
- `LG_IP` → IP del TV (actualmente `192.168.1.120`, verificar en el router)

### lg_keepalive.sh
**Propósito:** evitar que el chip WiFi del LG 43UJ6510-SA entre en deep sleep.

**Lógica:** cuando el TV está apagado (no responde a ping), intenta una conexión TCP al puerto 3000 (WebSocket webOS) para mantener el chip activo. Solo actúa cuando el TV está apagado.

**Nota:** efectividad limitada por el hardware del modelo 2017. Si el TV sigue sin responder al WoL, evaluar HDMI-CEC o Broadlink IR (~$20).

---

## Cron (tareas programadas)

```
*/1 * * * * /home/druminot/.local/bin/tuya_watchdog.sh
*/2 * * * * /home/druminot/.local/bin/lg_watchdog.sh
*/3 * * * * /home/druminot/.local/bin/lg_keepalive.sh
```

Ver con: `crontab -l`
Editar con: `crontab -e`
Logs en: `/tmp/tuya_watchdog.log` y `/tmp/lg_watchdog.log` y `/tmp/lg_keepalive.log`

---

## Firewall

Puertos TCP que deben estar abiertos para HomeKit:
```bash
sudo ufw allow 21063/tcp   # HomeKit Bridge (switches)
sudo ufw allow 21064/tcp   # HomeKit Accessory LG TV
```

---

## Home Assistant — Ubicación

- **Tipo:** Docker
- **Container name:** `homeassistant`
- **URL local:** http://localhost:8123
- **Config en host:** `/home/druminot/homeassistant/config/` (o vía `docker exec homeassistant`)

Para restaurar la configuración:
```bash
docker cp ha-config/configuration.yaml homeassistant:/config/
docker cp ha-config/automations.yaml homeassistant:/config/
docker cp ha-config/scripts.yaml homeassistant:/config/
# Reiniciar HA desde la UI o:
docker restart homeassistant
```

---

## Notas de IPv6

El servidor no tiene conectividad IPv6. Si Tuya falla con "Network unreachable", verificar `/etc/gai.conf`:
```
precedence ::ffff:0:0/96  100
```
Esto fuerza IPv4 sobre IPv6 en todas las conexiones. Ya está configurado permanentemente.
