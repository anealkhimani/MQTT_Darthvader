#!/usr/bin/env python3
"""
MQTT Service - Listens for MQTT topics and conditionally executes Python scripts
"""

import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, Any, Optional

import paho.mqtt.client as mqtt
from paho.mqtt.enums import CallbackAPIVersion

# Configuration
CONFIG_FILE = "/etc/mqtt-service/config.json"
LOG_FILE = "/var/log/mqtt-service/mqtt-service.log"
PID_FILE = "/var/run/mqtt-service.pid"

# Default configuration
DEFAULT_CONFIG = {
    "mqtt": {
        "broker": "localhost",
        "port": 1883,
        "username": None,
        "password": None,
        "client_id": "mqtt-service",
        "keepalive": 60
    },
    "topics": {
        "sensor/temperature": {
            "script": "/usr/local/bin/handle_temperature.py",
            "conditions": {
                "threshold": 25.0,
                "operator": ">"
            }
        },
        "device/status": {
            "script": "/usr/local/bin/handle_device_status.py",
            "conditions": {
                "status": "offline"
            }
        }
    },
    "logging": {
        "level": "INFO",
        "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    }
}


class MQTTService:
    def __init__(self, config_file: str = CONFIG_FILE):
        self.config_file = config_file
        self.config = self.load_config()
        self.client = None
        self.setup_logging()
        self.logger = logging.getLogger(__name__)
        
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file or use defaults"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    # Merge with defaults for missing keys
                    return self.merge_configs(DEFAULT_CONFIG, config)
            else:
                self.logger.warning(f"Config file {self.config_file} not found, using defaults")
                return DEFAULT_CONFIG
        except Exception as e:
            self.logger.error(f"Error loading config: {e}")
            return DEFAULT_CONFIG
    
    def merge_configs(self, default: Dict, user: Dict) -> Dict:
        """Recursively merge user config with defaults"""
        result = default.copy()
        for key, value in user.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self.merge_configs(result[key], value)
            else:
                result[key] = value
        return result
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_config = self.config.get('logging', {})
        log_level = getattr(logging, log_config.get('level', 'INFO').upper())
        log_format = log_config.get('format', DEFAULT_CONFIG['logging']['format'])
        
        # Create log directory if it doesn't exist
        log_dir = os.path.dirname(LOG_FILE)
        os.makedirs(log_dir, exist_ok=True)
        
        logging.basicConfig(
            level=log_level,
            format=log_format,
            handlers=[
                logging.FileHandler(LOG_FILE),
                logging.StreamHandler(sys.stdout)
            ]
        )
    
    def on_connect(self, client, userdata, flags, reason_code, properties=None):
        """Callback when connected to MQTT broker"""
        self.logger.info(f"Connected to MQTT broker with result code {reason_code}")
        
        # Subscribe to all configured topics
        for topic in self.config['topics'].keys():
            client.subscribe(topic)
            self.logger.info(f"Subscribed to topic: {topic}")
    
    def on_message(self, client, userdata, msg):
        """Callback when message is received"""
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        
        self.logger.info(f"Received message on {topic}: {payload}")
        
        # Check if topic is configured
        if topic in self.config['topics']:
            topic_config = self.config['topics'][topic]
            if self.should_execute_script(topic_config, payload):
                self.execute_script(topic_config['script'], topic, payload)
    
    def should_execute_script(self, topic_config: Dict, payload: str) -> bool:
        """Check if script should be executed based on conditions"""
        conditions = topic_config.get('conditions', {})
        
        if not conditions:
            return True  # No conditions means always execute
        
        try:
            # Try to parse payload as JSON
            data = json.loads(payload)
        except json.JSONDecodeError:
            # If not JSON, treat as string
            data = payload
        
        for key, expected_value in conditions.items():
            if key not in data:
                return False
            
            actual_value = data[key]
            
            # Handle different operators
            if isinstance(expected_value, dict) and 'operator' in expected_value:
                operator = expected_value['operator']
                threshold = expected_value.get('threshold', expected_value.get('value'))
                
                if operator == '>':
                    if not (isinstance(actual_value, (int, float)) and actual_value > threshold):
                        return False
                elif operator == '<':
                    if not (isinstance(actual_value, (int, float)) and actual_value < threshold):
                        return False
                elif operator == '>=':
                    if not (isinstance(actual_value, (int, float)) and actual_value >= threshold):
                        return False
                elif operator == '<=':
                    if not (isinstance(actual_value, (int, float)) and actual_value <= threshold):
                        return False
                elif operator == '==':
                    if actual_value != threshold:
                        return False
                elif operator == '!=':
                    if actual_value == threshold:
                        return False
            else:
                # Simple equality check
                if actual_value != expected_value:
                    return False
        
        return True
    
    def execute_script(self, script_path: str, topic: str, payload: str):
        """Execute the specified Python script"""
        if not os.path.exists(script_path):
            self.logger.error(f"Script not found: {script_path}")
            return
        
        try:
            # Set environment variables for the script
            env = os.environ.copy()
            env['MQTT_TOPIC'] = topic
            env['MQTT_PAYLOAD'] = payload
            
            # Execute the script
            result = subprocess.run(
                [sys.executable, script_path],
                env=env,
                capture_output=True,
                text=True,
                timeout=30  # 30 second timeout
            )
            
            if result.returncode == 0:
                self.logger.info(f"Script {script_path} executed successfully")
                if result.stdout:
                    self.logger.debug(f"Script output: {result.stdout}")
            else:
                self.logger.error(f"Script {script_path} failed with return code {result.returncode}")
                if result.stderr:
                    self.logger.error(f"Script error: {result.stderr}")
                    
        except subprocess.TimeoutExpired:
            self.logger.error(f"Script {script_path} timed out")
        except Exception as e:
            self.logger.error(f"Error executing script {script_path}: {e}")
    
    def on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties=None):
        """Callback when disconnected from MQTT broker"""
        self.logger.warning(f"Disconnected from MQTT broker: {reason_code}")
    
    def start(self):
        """Start the MQTT service"""
        mqtt_config = self.config['mqtt']
        
        # Create MQTT client
        self.client = mqtt.Client(
            callback_api_version=CallbackAPIVersion.VERSION2,
            client_id=mqtt_config['client_id']
        )
        
        # Set callbacks
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        
        # Set authentication if provided
        if mqtt_config.get('username'):
            self.client.username_pw_set(
                mqtt_config['username'],
                mqtt_config.get('password')
            )
        
        try:
            # Connect to broker
            self.client.connect(
                mqtt_config['broker'],
                mqtt_config['port'],
                mqtt_config['keepalive']
            )
            
            # Start the loop
            self.client.loop_forever()
            
        except Exception as e:
            self.logger.error(f"Failed to start MQTT service: {e}")
            sys.exit(1)
    
    def stop(self):
        """Stop the MQTT service"""
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
            self.logger.info("MQTT service stopped")


def write_pid_file():
    """Write PID to file"""
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))


def remove_pid_file():
    """Remove PID file"""
    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass


def main():
    """Main entry point"""
    import signal
    
    def signal_handler(signum, frame):
        """Handle shutdown signals"""
        logging.info(f"Received signal {signum}, shutting down...")
        if service:
            service.stop()
        remove_pid_file()
        sys.exit(0)
    
    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Write PID file
    write_pid_file()
    
    # Start service
    service = MQTTService()
    try:
        service.start()
    except KeyboardInterrupt:
        logging.info("Service interrupted by user")
    finally:
        service.stop()
        remove_pid_file()


if __name__ == "__main__":
    main() 