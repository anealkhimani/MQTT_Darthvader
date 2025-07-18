#!/bin/bash
# Example bash script to handle system backup triggers
# This script is called by the MQTT service when backup conditions are met

# Setup logging
LOG_FILE="/var/log/mqtt-service/backup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Get MQTT data from environment variables
TOPIC="$MQTT_TOPIC"
PAYLOAD="$MQTT_PAYLOAD"

echo "$(date): Backup script triggered"
echo "Topic: $TOPIC"
echo "Payload: $PAYLOAD"

# Parse JSON payload if it's JSON
if [[ "$PAYLOAD" =~ ^\{.*\}$ ]]; then
    # Extract values using jq if available, otherwise use grep/sed
    if command -v jq &> /dev/null; then
        BACKUP_TYPE=$(echo "$PAYLOAD" | jq -r '.backup_type // "full"')
        TARGET_DIR=$(echo "$PAYLOAD" | jq -r '.target_dir // "/backup"')
        COMPRESS=$(echo "$PAYLOAD" | jq -r '.compress // "true"')
    else
        # Fallback parsing without jq
        BACKUP_TYPE=$(echo "$PAYLOAD" | grep -o '"backup_type":"[^"]*"' | cut -d'"' -f4 || echo "full")
        TARGET_DIR=$(echo "$PAYLOAD" | grep -o '"target_dir":"[^"]*"' | cut -d'"' -f4 || echo "/backup")
        COMPRESS=$(echo "$PAYLOAD" | grep -o '"compress":"[^"]*"' | cut -d'"' -f4 || echo "true")
    fi
else
    # Plain text payload
    BACKUP_TYPE="full"
    TARGET_DIR="/backup"
    COMPRESS="true"
fi

echo "Backup type: $BACKUP_TYPE"
echo "Target directory: $TARGET_DIR"
echo "Compress: $COMPRESS"

# Create backup directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Perform backup based on type
case "$BACKUP_TYPE" in
    "full")
        echo "Starting full system backup..."
        
        # Example: Backup important directories
        BACKUP_FILE="$TARGET_DIR/full_backup_$(date +%Y%m%d_%H%M%S).tar"
        
        if [ "$COMPRESS" = "true" ]; then
            BACKUP_FILE="$BACKUP_FILE.gz"
            tar -czf "$BACKUP_FILE" /etc /home /var/log 2>/dev/null || {
                echo "ERROR: Full backup failed"
                exit 1
            }
        else
            tar -cf "$BACKUP_FILE" /etc /home /var/log 2>/dev/null || {
                echo "ERROR: Full backup failed"
                exit 1
            }
        fi
        
        echo "Full backup completed: $BACKUP_FILE"
        ;;
        
    "config")
        echo "Starting configuration backup..."
        
        BACKUP_FILE="$TARGET_DIR/config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$BACKUP_FILE" /etc 2>/dev/null || {
            echo "ERROR: Config backup failed"
            exit 1
        }
        
        echo "Configuration backup completed: $BACKUP_FILE"
        ;;
        
    "database")
        echo "Starting database backup..."
        
        # Example: Backup MySQL/MariaDB (adjust as needed)
        BACKUP_FILE="$TARGET_DIR/db_backup_$(date +%Y%m%d_%H%M%S).sql"
        
        if command -v mysqldump &> /dev/null; then
            mysqldump --all-databases > "$BACKUP_FILE" 2>/dev/null || {
                echo "ERROR: Database backup failed"
                exit 1
            }
            echo "Database backup completed: $BACKUP_FILE"
        else
            echo "WARNING: mysqldump not found, skipping database backup"
        fi
        ;;
        
    *)
        echo "ERROR: Unknown backup type: $BACKUP_TYPE"
        exit 1
        ;;
esac

# Clean up old backups (keep last 7 days)
find "$TARGET_DIR" -name "*backup*" -type f -mtime +7 -delete 2>/dev/null || true

# Send notification (example)
echo "Backup completed successfully at $(date)" | logger -t mqtt-backup

echo "$(date): Backup script completed successfully" 