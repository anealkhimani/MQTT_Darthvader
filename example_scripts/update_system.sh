#!/bin/bash
# Example bash script to handle system update triggers
# This script is called by the MQTT service when update conditions are met

# Setup logging
LOG_FILE="/var/log/mqtt-service/update.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Get MQTT data from environment variables
TOPIC="$MQTT_TOPIC"
PAYLOAD="$MQTT_PAYLOAD"

echo "$(date): Update script triggered"
echo "Topic: $TOPIC"
echo "Payload: $PAYLOAD"

# Parse JSON payload if it's JSON
if [[ "$PAYLOAD" =~ ^\{.*\}$ ]]; then
    # Extract values using jq if available, otherwise use grep/sed
    if command -v jq &> /dev/null; then
        UPDATE_TYPE=$(echo "$PAYLOAD" | jq -r '.update_type // "security"')
        PRIORITY=$(echo "$PAYLOAD" | jq -r '.priority // "normal"')
        PACKAGES=$(echo "$PAYLOAD" | jq -r '.packages // "all"')
        REBOOT=$(echo "$PAYLOAD" | jq -r '.reboot // "false"')
    else
        # Fallback parsing without jq
        UPDATE_TYPE=$(echo "$PAYLOAD" | grep -o '"update_type":"[^"]*"' | cut -d'"' -f4 || echo "security")
        PRIORITY=$(echo "$PAYLOAD" | grep -o '"priority":"[^"]*"' | cut -d'"' -f4 || echo "normal")
        PACKAGES=$(echo "$PAYLOAD" | grep -o '"packages":"[^"]*"' | cut -d'"' -f4 || echo "all")
        REBOOT=$(echo "$PAYLOAD" | grep -o '"reboot":"[^"]*"' | cut -d'"' -f4 || echo "false")
    fi
else
    # Plain text payload
    UPDATE_TYPE="security"
    PRIORITY="normal"
    PACKAGES="all"
    REBOOT="false"
fi

echo "Update type: $UPDATE_TYPE"
echo "Priority: $PRIORITY"
echo "Packages: $PACKAGES"
echo "Reboot: $REBOOT"

# Check if we should proceed based on priority
if [ "$PRIORITY" != "high" ] && [ "$PRIORITY" != "critical" ]; then
    echo "Update priority is not high enough, skipping"
    exit 0
fi

# Create update lock file to prevent concurrent updates
LOCK_FILE="/var/run/mqtt-update.lock"
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$PID" 2>/dev/null; then
        echo "Update already in progress (PID: $PID), skipping"
        exit 0
    else
        echo "Removing stale lock file"
        rm -f "$LOCK_FILE"
    fi
fi

echo $$ > "$LOCK_FILE"

# Function to cleanup lock file
cleanup() {
    rm -f "$LOCK_FILE"
    echo "$(date): Update script completed"
}

trap cleanup EXIT

# Update package list
echo "Updating package list..."
apt update || {
    echo "ERROR: Failed to update package list"
    exit 1
}

# Perform update based on type
case "$UPDATE_TYPE" in
    "security")
        echo "Performing security updates..."
        
        # Get list of security updates
        SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | cut -d'/' -f1 | tr '\n' ' ')
        
        if [ -n "$SECURITY_UPDATES" ]; then
            echo "Security updates available: $SECURITY_UPDATES"
            apt install -y $SECURITY_UPDATES || {
                echo "ERROR: Security update failed"
                exit 1
            }
        else
            echo "No security updates available"
        fi
        ;;
        
    "all")
        echo "Performing full system update..."
        
        if [ "$PACKAGES" = "all" ]; then
            apt upgrade -y || {
                echo "ERROR: Full system update failed"
                exit 1
            }
        else
            # Update specific packages
            apt install -y $PACKAGES || {
                echo "ERROR: Package update failed"
                exit 1
            }
        fi
        ;;
        
    "dist-upgrade")
        echo "Performing distribution upgrade..."
        apt dist-upgrade -y || {
            echo "ERROR: Distribution upgrade failed"
            exit 1
        }
        ;;
        
    *)
        echo "ERROR: Unknown update type: $UPDATE_TYPE"
        exit 1
        ;;
esac

# Clean up old packages
echo "Cleaning up old packages..."
apt autoremove -y
apt autoclean

# Check if reboot is required
if [ "$REBOOT" = "true" ] || [ -f /var/run/reboot-required ]; then
    echo "Reboot required, scheduling reboot in 5 minutes..."
    echo "Reboot scheduled by MQTT service at $(date)" | logger -t mqtt-update
    shutdown -r +5 "System update completed, rebooting in 5 minutes"
else
    echo "No reboot required"
fi

# Send notification
echo "System update completed successfully at $(date)" | logger -t mqtt-update

echo "$(date): Update script completed successfully" 