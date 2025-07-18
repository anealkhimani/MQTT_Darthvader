#!/usr/bin/env python3
"""
Example script to handle temperature sensor data
This script is called by the MQTT service when temperature conditions are met
"""

import json
import logging
import os
import sys
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main function to handle temperature data"""
    
    # Get MQTT data from environment variables
    topic = os.environ.get('MQTT_TOPIC', 'unknown')
    payload = os.environ.get('MQTT_PAYLOAD', '{}')
    
    logger.info(f"Handling temperature data from topic: {topic}")
    logger.info(f"Payload: {payload}")
    
    try:
        # Parse the payload
        data = json.loads(payload)
        
        # Extract temperature value
        temperature = data.get('temperature')
        if temperature is None:
            logger.error("No temperature value found in payload")
            sys.exit(1)
        
        # Log the temperature
        logger.info(f"Current temperature: {temperature}°C")
        
        # Example actions based on temperature
        if temperature > 30:
            logger.warning(f"High temperature alert: {temperature}°C")
            # You could send an email, SMS, or trigger other actions here
            send_alert(f"High temperature detected: {temperature}°C")
            
        elif temperature < 10:
            logger.warning(f"Low temperature alert: {temperature}°C")
            send_alert(f"Low temperature detected: {temperature}°C")
            
        # Store temperature data (example)
        store_temperature_data(temperature, data)
        
        # You can add more logic here:
        # - Control HVAC systems
        # - Send data to external APIs
        # - Update databases
        # - Trigger other automation
        
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse JSON payload: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error handling temperature data: {e}")
        sys.exit(1)

def send_alert(message):
    """Send an alert (example implementation)"""
    # This is where you would implement your alert mechanism
    # Examples: email, SMS, webhook, etc.
    logger.info(f"ALERT: {message}")
    
    # Example: Write to a log file
    with open('/var/log/mqtt-service/alerts.log', 'a') as f:
        timestamp = datetime.now().isoformat()
        f.write(f"{timestamp} - {message}\n")

def store_temperature_data(temperature, data):
    """Store temperature data (example implementation)"""
    # This is where you would implement data storage
    # Examples: database, file, external API, etc.
    
    # Example: Append to a CSV file
    csv_file = '/var/log/mqtt-service/temperature_data.csv'
    
    # Create file with headers if it doesn't exist
    if not os.path.exists(csv_file):
        with open(csv_file, 'w') as f:
            f.write("timestamp,temperature,humidity,location\n")
    
    # Append data
    timestamp = datetime.now().isoformat()
    humidity = data.get('humidity', 'N/A')
    location = data.get('location', 'unknown')
    
    with open(csv_file, 'a') as f:
        f.write(f"{timestamp},{temperature},{humidity},{location}\n")
    
    logger.info(f"Temperature data stored: {temperature}°C")

if __name__ == "__main__":
    main() 