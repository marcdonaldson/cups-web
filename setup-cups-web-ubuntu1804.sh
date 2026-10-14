#!/bin/bash
# Setup script for CUPS-Web on Ubuntu 18.04
# This script installs Docker (if needed), creates the container with proper CUPS settings,
# volumes, and environment for USB printers, AirPrint, etc.
# Based on https://github.com/hanxi/cups-web (English companion: https://github.com/marcdonaldson/cups-web)

set -e

echo "=== CUPS-Web Setup for Ubuntu 18.04 ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Update system
apt-get update -qq

# Install prerequisites
apt-get install -y -qq apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Install Docker if not present
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io
  systemctl enable docker
  systemctl start docker
  echo "Docker installed."
else
  echo "Docker already installed."
fi

# Install Docker Compose (v1 compatible for Ubuntu 18.04, or v2 plugin)
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  echo "Installing Docker Compose..."
  # Use v1 for better compatibility with 18.04
  curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  echo "Docker Compose installed."
else
  echo "Docker Compose already available."
fi

# Create working directory
INSTALL_DIR="${1:-/opt/cups-web}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "Working directory: $INSTALL_DIR"

# Create directories for persistence
mkdir -p .etc .data .uploads .drivers .scans

# Create .env file with defaults (customize as needed)
if [ ! -f .env ]; then
  cat > .env << 'ENVFILE'
# CUPS admin credentials (used by cupsd)
CUPSADMIN=print
CUPSPASSWORD=print

# Timezone
TZ=UTC

# Web listen address (host network mode, default :1180)
LISTEN_ADDR=:1180

# Scan output dir inside container
SCAN_DIR=/scans

# Optional: for web-only mode connecting to external CUPS
# CUPS_HOST=192.168.1.100:631
# CUPS_SOCKET_PATH=/var/run/cups/cups.sock
ENVFILE
  echo "Created .env with defaults (CUPSADMIN=print, CUPSPASSWORD=print, LISTEN_ADDR=:1180)"
fi

# Create docker-compose.yml (host network for mDNS/AirPrint + USB support)
cat > docker-compose.yml << 'COMPOSE'
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
COMPOSE

echo "Created docker-compose.yml"

# Stop host avahi if running (conflicts with container avahi on host network)
if systemctl is-active --quiet avahi-daemon; then
  echo "Stopping host avahi-daemon to avoid port 5353 conflict..."
  systemctl stop avahi-daemon || true
  systemctl disable avahi-daemon || true
fi

# Pull and start
echo "Pulling image and starting container..."
if command -v docker-compose &> /dev/null; then
  docker-compose pull
  docker-compose up -d
else
  docker compose pull
  docker compose up -d
fi

echo ""
echo "=== Setup complete ==="
echo "Web UI: http://$(hostname -I | awk '{print $1}'):1180  (or http://localhost:1180)"
echo "Default login: admin / admin"
echo "CUPS admin: print / print (from .env)"
echo ""
echo "Useful commands:"
echo "  cd $INSTALL_DIR"
echo "  docker-compose logs -f cups          # view logs"
echo "  docker-compose restart cups          # restart"
echo "  docker exec cups driver-list         # list drivers"
echo "  docker exec cups lpstat -p           # list printers"
echo ""
echo "To change ports/credentials, edit $INSTALL_DIR/.env and restart."
echo "For USB printers: plug in after start if needed; privileged + /dev/bus/usb enables hotplug."
echo "AirPrint/mDNS works via host network mode."
echo ""
echo "Note: Original project UI is in Chinese. See https://github.com/marcdonaldson/cups-web for English notes/translation progress."
