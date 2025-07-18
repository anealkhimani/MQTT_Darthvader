#!/bin/bash
# MQTT Service Installation Script for Ubuntu
# This script installs the MQTT service as a systemd service

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
SCRIPT_DIR="/usr/local/bin"

echo -e "${GREEN}MQTT Service Installation Script${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Update package list
echo -e "${YELLOW}Updating package list...${NC}"
apt update

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt install -y python3 python3-pip python3-venv

# Create service user and group
echo -e "${YELLOW}Creating service user and group...${NC}"
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false "$SERVICE_USER"
    echo "Created user: $SERVICE_USER"
else
    echo "User $SERVICE_USER already exists"
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$SCRIPT_DIR"

# Set permissions
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$LOG_DIR"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$CONFIG_DIR"
chmod 755 "$LOG_DIR"
chmod 755 "$CONFIG_DIR"

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip3 install paho-mqtt

# Copy service files
echo -e "${YELLOW}Installing service files...${NC}"

# Copy the main service script
if [ -f "mqtt_service.py" ]; then
    cp mqtt_service.py "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/mqtt_service.py"
    chown "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR/mqtt_service.py"
    echo "Installed mqtt_service.py"
else
    echo -e "${RED}Error: mqtt_service.py not found in current directory${NC}"
    exit 1
fi

# Copy configuration file
if [ -f "config.json" ]; then
    cp config.json "$CONFIG_DIR/"
    chown "$SERVICE_USER:$SERVICE_GROUP" "$CONFIG_DIR/config.json"
    chmod 644 "$CONFIG_DIR/config.json"
    echo "Installed config.json"
else
    echo -e "${YELLOW}Warning: config.json not found, using default configuration${NC}"
fi

# Copy example scripts
if [ -d "example_scripts" ]; then
    cp -r example_scripts/* "$SCRIPT_DIR/"
    chmod +x "$SCRIPT_DIR"/*.py "$SCRIPT_DIR"/*.sh
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SCRIPT_DIR"/*.py "$SCRIPT_DIR"/*.sh
    echo "Installed example scripts"
fi

# Install systemd service
if [ -f "mqtt-service.service" ]; then
    cp mqtt-service.service /etc/systemd/system/
    chmod 644 /etc/systemd/system/mqtt-service.service
    echo "Installed systemd service"
else
    echo -e "${RED}Error: mqtt-service.service not found in current directory${NC}"
    exit 1
fi

# Reload systemd and enable service
echo -e "${YELLOW}Configuring systemd service...${NC}"
systemctl daemon-reload
systemctl enable mqtt-service

# Create log rotation configuration
echo -e "${YELLOW}Configuring log rotation...${NC}"
cat > /etc/logrotate.d/mqtt-service << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_GROUP
    postrotate
        systemctl reload mqtt-service > /dev/null 2>&1 || true
    endscript
}
EOF

echo -e "${GREEN}Installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit configuration file: $CONFIG_DIR/config.json"
echo "2. Create your custom Python scripts in: $SCRIPT_DIR"
echo "3. Start the service: systemctl start mqtt-service"
echo "4. Check status: systemctl status mqtt-service"
echo "5. View logs: journalctl -u mqtt-service -f"
echo ""
echo -e "${YELLOW}Service commands:${NC}"
echo "  Start:   systemctl start mqtt-service"
echo "  Stop:    systemctl stop mqtt-service"
echo "  Restart: systemctl restart mqtt-service"
echo "  Status:  systemctl status mqtt-service"
echo "  Logs:    journalctl -u mqtt-service -f"
echo ""
echo -e "${GREEN}MQTT Service is ready to use!${NC}" 