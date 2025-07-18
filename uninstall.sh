#!/bin/bash
# MQTT Service Uninstall Script for Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="mqtt-service"
SERVICE_USER="mqtt-service"
SERVICE_GROUP="mqtt-service"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/mqtt-service"
LOG_DIR="/var/log/mqtt-service"

echo -e "${GREEN}MQTT Service Uninstall Script${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Stop and disable service
echo -e "${YELLOW}Stopping and disabling service...${NC}"
systemctl stop mqtt-service 2>/dev/null || true
systemctl disable mqtt-service 2>/dev/null || true

# Remove systemd service file
echo -e "${YELLOW}Removing systemd service...${NC}"
rm -f /etc/systemd/system/mqtt-service.service
systemctl daemon-reload

# Remove service files
echo -e "${YELLOW}Removing service files...${NC}"
rm -f "$INSTALL_DIR/mqtt_service.py"

# Remove configuration
echo -e "${YELLOW}Removing configuration...${NC}"
rm -rf "$CONFIG_DIR"

# Remove log rotation configuration
echo -e "${YELLOW}Removing log rotation configuration...${NC}"
rm -f /etc/logrotate.d/mqtt-service

# Ask about removing logs
read -p "Do you want to remove log files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing log files...${NC}"
    rm -rf "$LOG_DIR"
else
    echo -e "${YELLOW}Log files preserved at: $LOG_DIR${NC}"
fi

# Ask about removing service user
read -p "Do you want to remove the service user ($SERVICE_USER)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing service user...${NC}"
    userdel "$SERVICE_USER" 2>/dev/null || true
    groupdel "$SERVICE_GROUP" 2>/dev/null || true
else
    echo -e "${YELLOW}Service user preserved: $SERVICE_USER${NC}"
fi

# Ask about removing Python dependencies
read -p "Do you want to remove paho-mqtt Python package? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing Python dependencies...${NC}"
    pip3 uninstall -y paho-mqtt 2>/dev/null || true
else
    echo -e "${YELLOW}Python dependencies preserved${NC}"
fi

echo -e "${GREEN}Uninstallation completed!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC}"
echo "- Service has been stopped and disabled"
echo "- Configuration files have been removed"
echo "- Log files may still exist (check $LOG_DIR)"
echo "- Service user may still exist (check with: id $SERVICE_USER)"
echo "- Python packages may still be installed (check with: pip3 list | grep paho-mqtt)" 