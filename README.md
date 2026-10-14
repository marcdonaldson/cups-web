# 🖨️ CUPS Web — Web Print Management (English)

[![GitHub Release](https://img.shields.io/github/v/release/hanxi/cups-web?style=flat-square&logo=github&color=blue)](https://github.com/hanxi/cups-web/releases)
[![Docker Pulls](https://img.shields.io/docker/pulls/hanxi/cups-web?style=flat-square&logo=docker)](https://hub.docker.com/r/hanxi/cups-web)

**Original project**: [hanxi/cups-web](https://github.com/hanxi/cups-web) (Chinese UI & docs)

This repository provides an **English-oriented fork / companion** for the excellent CUPS Web project.  
The core binary and Docker image remain the same (`hanxi/cups-web`).  
This repo focuses on:

- Fully English README and documentation
- Ubuntu 18.04 (and general Linux) one-click setup script
- Notes on translating the Vue frontend from Chinese to English
- Clear configuration for CUPS credentials, ports, USB printers, AirPrint, etc.

> **Status of frontend translation**: The original Vue frontend (Login, Print, Admin, Drivers, Scan, Scheduled tasks, etc.) contains many Chinese strings. A complete i18n / English conversion is non-trivial (20+ Vue files + backend message maps).  
> Contributions welcome — start from the `frontend/src` directory of the upstream repo.  
> You can already use the Docker image with the original (Chinese) UI; the Web UI works regardless of language.

## What is CUPS Web?

A web-based print management tool built on CUPS.  
Upload files from a browser, submit print jobs remotely, manage multiple users, track print history. Ideal for home and small office.

**Key features** (from upstream):

- Multi-format support: PDF, images (JPG/PNG/GIF/HEIC), Office (doc/docx/xls/xlsx/ppt/pptx), OFD, plain text
- Automatic conversion (LibreOffice, ofdrw Java converter, server-side rendering)
- Print options: copies, duplex, color/B&W, paper size, media type, quality, orientation, page range, scale, mirror
- Real-time PDF preview
- Photo scheduled queue (print one photo per day/week/month)
- Scanning support (scanimage + SANE)
- Extensive printer driver management (pre-installed + on-demand vendor drivers: Canon UFR/CAPT, HP, Epson, etc.)
- Multi-user (admin / user roles), API keys, session + CSRF security
- AIO Docker image with CUPS + web + drivers + converters

## Quick Start (Ubuntu 18.04 / any modern Linux)

### One-click script

```bash
# Download and run (as root)
curl -fsSL https://raw.githubusercontent.com/marcdonaldson/cups-web/main/setup-cups-web-ubuntu1804.sh -o setup-cups-web.sh
chmod +x setup-cups-web.sh
sudo ./setup-cups-web.sh /opt/cups-web   # optional install dir, default /opt/cups-web
```

The script will:

1. Install Docker + Docker Compose if missing
2. Create persistent directories (`.etc`, `.data`, `.uploads`, `.drivers`, `.scans`)
3. Write a production-ready `docker-compose.yml` (host network for AirPrint/mDNS + USB hotplug)
4. Write `.env` with sensible defaults
5. Stop host avahi-daemon if present (to avoid 5353 conflict)
6. Pull `hanxi/cups-web:latest` and start the container

### Manual Docker Compose

```yaml
# docker-compose.yml
services:
  cups:
    image: hanxi/cups-web:latest
    container_name: cups
    user: root
    hostname: CUPS
    network_mode: host
    security_opt:
      - apparmor:unconfined
    environment:
      - CUPSADMIN=${CUPSADMIN:-print}
      - CUPSPASSWORD=${CUPSPASSWORD:-print}
      - TZ=${TZ:-UTC}
      - LISTEN_ADDR=${LISTEN_ADDR:-:1180}
      - SCAN_DIR=${SCAN_DIR:-/scans}
    volumes:
      - ./.etc:/etc/cups
      - ./.data:/data
      - ./.uploads:/uploads
      - ./.scans:/scans
      - ./.drivers:/opt/cups-drivers/data
      - /dev/bus/usb:/dev/bus/usb
      - /run/udev:/run/udev:ro
    tmpfs:
      - /run/dbus
      - /run/avahi-daemon
    device_cgroup_rules:
      - 'c 189:* rmw'
    privileged: true
    restart: unless-stopped
```

```bash
# .env
CUPSADMIN=print
CUPSPASSWORD=your_secure_password
TZ=UTC
LISTEN_ADDR=:1180
```

```bash
docker compose up -d
```

### Access

- **Web UI**: http://YOUR_IP:1180  
  Default login: `admin` / `admin` (change immediately)
- **CUPS classic UI**: http://YOUR_IP:631  
  Admin: value of `CUPSADMIN` / `CUPSPASSWORD` (default `print`/`print`)

### Important notes for Ubuntu 18.04 / older systems

- Use Docker CE from official repo (script does this)
- Docker Compose v1.29.x is used for compatibility; modern `docker compose` also works if available
- `privileged: true` + `/dev/bus/usb` mount is required for reliable USB printer detection and hotplug on many ARM / embedded boards and some x86 setups
- Host network mode is required for AirPrint / mDNS discovery and advertisement
- If you already run avahi-daemon on the host, stop/disable it (script does this)

### Reset admin password

```bash
docker compose down
rm ./.data/cups-web.db
docker compose up -d
# back to admin/admin
```

### Driver management

Most printers work with the pre-installed drivers. For vendor-specific ones:

1. Login as admin → **Drivers** page (Chinese: 驱动)
2. Scan printers → one-click install + add to CUPS
3. Or CLI: `docker exec cups driver-list` / `driver-install <name>`

Drivers persist in `./.drivers`.

## Translating the Frontend

The upstream frontend is Vue 3 + Vite + Nuxt UI + Tailwind.

Key files containing Chinese UI strings:

- `frontend/src/views/*.vue` (LoginView, PrintView, AdminView, DriversView, ScanView, ScheduledView, ApiKeysView)
- `frontend/src/components/print/*.vue`
- Message maps in LoginView and elsewhere that localize backend English errors into Chinese

Recommended approach for a full English version:

1. Fork upstream
2. Introduce `vue-i18n` (or simple string maps)
3. Extract all hard-coded Chinese strings
4. Provide `en` locale
5. Optionally keep Chinese as fallback

Pull requests that add English locale to the original project would be the cleanest long-term solution.

## Credits

- Original author & project: [hanxi](https://github.com/hanxi) — [cups-web](https://github.com/hanxi/cups-web)
- License: MIT (same as upstream)

## License

MIT
