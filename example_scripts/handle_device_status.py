#!/usr/bin/env python3
"""
Example script to handle device status changes
This script is called by the MQTT service when device status conditions are met
"""

import json
import logging
import os
import sys
import subprocess
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main function to handle device status changes"""
    
    # Get MQTT data from environment variables
    topic = os.environ.get('MQTT_TOPIC', 'unknown')
    payload = os.environ.get('MQTT_PAYLOAD', '{}')
    
    logger.info(f"Handling device status from topic: {topic}")
    logger.info(f"Payload: {payload}")
    
    try:
        # Parse the payload
        data = json.loads(payload)
        
        # Extract device information
        device_id = data.get('device_id', 'unknown')
        status = data.get('status', 'unknown')
        timestamp = data.get('timestamp', datetime.now().isoformat())
        
        logger.info(f"Device {device_id} status: {status}")
        
        # Handle different status changes
        if status == 'offline':
            handle_device_offline(device_id, data)
        elif status == 'online':
            handle_device_online(device_id, data)
        elif status == 'error':
            handle_device_error(device_id, data)
        else:
            logger.info(f"Device {device_id} status changed to: {status}")
        
        # Store device status (example)
        store_device_status(device_id, status, data)
        
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse JSON payload: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error handling device status: {e}")
        sys.exit(1)

def handle_device_offline(device_id, data):
    """Handle device going offline"""
    logger.warning(f"Device {device_id} went offline")
    
    # Example actions for offline device:
    # - Send notification
    # - Update monitoring dashboard
    # - Trigger failover procedures
    # - Log the event
    
    send_notification(f"Device {device_id} is offline", "warning")
    
    # Example: Update a status file
    status_file = f"/var/log/mqtt-service/device_status/{device_id}.json"
    os.makedirs(os.path.dirname(status_file), exist_ok=True)
    
    status_data = {
        "device_id": device_id,
        "status": "offline",
        "last_seen": data.get('timestamp', datetime.now().isoformat()),
        "reason": data.get('reason', 'unknown')
    }
    
    with open(status_file, 'w') as f:
        json.dump(status_data, f, indent=2)

def handle_device_online(device_id, data):
    """Handle device coming online"""
    logger.info(f"Device {device_id} came online")
    
    # Example actions for online device:
    # - Send welcome notification
    # - Update status
    # - Trigger health checks
    
    send_notification(f"Device {device_id} is back online", "info")
    
    # Example: Update status file
    status_file = f"/var/log/mqtt-service/device_status/{device_id}.json"
    os.makedirs(os.path.dirname(status_file), exist_ok=True)
    
    status_data = {
        "device_id": device_id,
        "status": "online",
        "last_seen": data.get('timestamp', datetime.now().isoformat()),
        "uptime": data.get('uptime', 0)
    }
    
    with open(status_file, 'w') as f:
        json.dump(status_data, f, indent=2)

def handle_device_error(device_id, data):
    """Handle device error"""
    error_msg = data.get('error', 'Unknown error')
    logger.error(f"Device {device_id} error: {error_msg}")
    
    # Example actions for device error:
    # - Send critical alert
    # - Log detailed error information
    # - Trigger recovery procedures
    
    send_notification(f"Device {device_id} error: {error_msg}", "critical")
    
    # Example: Log error details
    error_log_file = "/var/log/mqtt-service/device_errors.log"
    with open(error_log_file, 'a') as f:
        timestamp = datetime.now().isoformat()
        f.write(f"{timestamp} - Device {device_id}: {error_msg}\n")

def send_notification(message, level):
    """Send notification (example implementation)"""
    # This is where you would implement your notification mechanism
    # Examples: email, SMS, Slack, webhook, etc.
    logger.info(f"NOTIFICATION [{level.upper()}]: {message}")
    
    # Example: Write to notification log
    with open('/var/log/mqtt-service/notifications.log', 'a') as f:
        timestamp = datetime.now().isoformat()
        f.write(f"{timestamp} - [{level.upper()}] {message}\n")

def store_device_status(device_id, status, data):
    """Store device status (example implementation)"""
    # This is where you would implement data storage
    # Examples: database, file, external API, etc.
    
    # Example: Append to a CSV file
    csv_file = '/var/log/mqtt-service/device_status_history.csv'
    
    # Create file with headers if it doesn't exist
    if not os.path.exists(csv_file):
        with open(csv_file, 'w') as f:
            f.write("timestamp,device_id,status,reason,uptime\n")
    
    # Append data
    timestamp = data.get('timestamp', datetime.now().isoformat())
    reason = data.get('reason', 'N/A')
    uptime = data.get('uptime', 'N/A')
    
    with open(csv_file, 'a') as f:
        f.write(f"{timestamp},{device_id},{status},{reason},{uptime}\n")
    
    logger.info(f"Device status stored: {device_id} - {status}")

if __name__ == "__main__":
    main() 