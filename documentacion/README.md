# Belén IA — Respaldo Home Assistant

Guía completa para replicar la configuración de Home Assistant en caso de reinstalación o migración.

---

## Estructura del respaldo

```
Belén IA respaldo/
├── scripts/
│   ├── tuya_watchdog.sh      ← Mantiene Tuya activo y reconecta si cae
│   └── lg_watchdog.sh        ← Reconecta el TV LG si HA lo pierde
├── ha-config/
│   ├── configuration.yaml    ← Config principal de HA (HomeKit Bridge)
│   ├── automations.yaml      ← Control remoto del LG via HomeKit (flechas, OK, etc.)
│   └── scripts.yaml          ← Scripts de botones del TV LG
└── documentacion/
    └── README.md             ← Este archivo
```

---

## Integraciones instaladas

### 1. Tuya (SmartLife)
- **Qué hace:** conecta todos los enchufes e interruptores SmartLife a HA
- **Cómo reinstalar:** Configuración → Dispositivos y servicios → Añadir integración → Tuya
- **Cuenta:** requiere cuenta en https://iot.tuya.com (Client ID + Client Secret)

### 2. LG webOS TV
- **TV:** LG 43UJ6510-SA — IP fija `192.168.1.120`
- **MAC (para WoL):** `a0:6f:aa:b9:bd:38`
- **Cómo reinstalar:** Configuración → Añadir integración → LG webOS Smart TV → ingresar IP
- **Nota:** el TV debe estar encendido al hacer el emparejamiento (acepta el popup en pantalla)
- **Activar en el TV:** Quick Start+ (Configuración → General → Quick Start+) para que responda en standby

### 3. Samsung TV 50" QLED
- **Cómo reinstalar:** Configuración → Añadir integración → Samsung Smart TV

### 4. Apple TV (x2)
- **Ubicación:** Sala
- **Cómo reinstalar:** Configuración → Añadir integración → Apple TV

### 5. HomeKit Bridge
- **Puerto:** 21063
- **Qué expone:** switches Tuya + TV LG (media_player)
- **Dispositivos excluidos** (no aparecen en Casa):
  - switch.dormitorio_interruptor_2
  - switch.oficina_interruptor_1
  - switch.oficina_interruptor_2
  - switch.centro_salon_interruptor_1
  - switch.centro_salon_interruptor_2
  - switch.salon_interruptor_1
  - switch.salon_interruptor_2
- **Vincular con iPhone:** app Casa → + → Agregar accesorio → escanear QR desde HA

### 6. Wake-on-LAN
- Habilitado en `configuration.yaml` para encender el LG desde HA/Siri
- Requiere que el TV tenga activado "Encender TV de forma remota" en su configuración

---

## Scripts de automatización (ha-config/)

### automations.yaml
9 automatizaciones para el control remoto del LG via HomeKit:
- Flechas ↑↓←→ → UP/DOWN/LEFT/RIGHT
- Botón central (select) → ENTER
- Atrás (back) → BACK
- Salir (exit) → EXIT
- Info (information) → HOME (pantalla principal del LG)
- WoL: cuando HomeKit manda `turn_on` al media_player → envía magic packet al LG

### scripts.yaml
7 scripts de botones (redundancia manual): LG Arriba, Abajo, Izquierda, Derecha, OK, Atrás, Home.

---

## Watchdogs (scripts/)

### tuya_watchdog.sh
**Propósito:** mantener la integración Tuya conectada permanentemente.

**Dos funciones:**
1. **Keepalive** — consulta el estado de un switch cada 2 min para que el MQTT de Tuya no entre en idle
2. **Auto-recovery** — si Tuya cae en `setup_error`, la recarga automáticamente

**Cómo instalar:**
```bash
cp tuya_watchdog.sh ~/.local/bin/tuya_watchdog.sh
chmod +x ~/.local/bin/tuya_watchdog.sh
# Agregar al crontab:
crontab -e
# Agregar línea: */2 * * * * /home/druminot/.local/bin/tuya_watchdog.sh
```

**Variables a actualizar si se reinstala HA:**
- `TOKEN` → nuevo token de larga duración (HA → Perfil → Tokens de acceso)
- `TUYA_ENTRY` → nuevo entry_id de Tuya (visible en la URL al abrir la integración en HA)

### lg_watchdog.sh
**Propósito:** reconectar el TV LG cuando HA pierde la conexión WebOS.

**Lógica:**
- Si el TV responde a ping pero HA lo ve `unavailable` → recarga la integración webOS
- Si el TV no responde a ping → está apagado, no hace nada

**Cómo instalar:** igual que tuya_watchdog.sh (ver arriba).

**Variables a actualizar:**
- `TOKEN` → mismo token de larga duración
- `LG_ENTRY` → entry_id de la integración LG webOS en HA
- `LG_IP` → IP del TV (actualmente `192.168.1.120`, verificar en el router)

---

## Cron (tareas programadas)

```
*/2 * * * * /home/druminot/.local/bin/tuya_watchdog.sh
*/2 * * * * /home/druminot/.local/bin/lg_watchdog.sh
```

Ver con: `crontab -l`
Editar con: `crontab -e`
Logs en: `/tmp/tuya_watchdog.log` y `/tmp/lg_watchdog.log`

---

## Firewall

Puerto `21063` (TCP) debe estar abierto para que el iPhone pueda vincular el HomeKit Bridge:
```bash
sudo ufw allow 21063/tcp
```

---

## Home Assistant — Ubicación

- **Tipo:** Docker
- **URL local:** http://localhost:8123
- **Config:** `/home/druminot/homeassistant/config/`

Para restaurar la configuración:
```bash
cp ha-config/configuration.yaml /home/druminot/homeassistant/config/
cp ha-config/automations.yaml /home/druminot/homeassistant/config/
cp ha-config/scripts.yaml /home/druminot/homeassistant/config/
# Reiniciar HA desde la UI o:
docker restart homeassistant
```
