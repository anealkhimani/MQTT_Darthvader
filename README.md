# MQTT Service for Ubuntu

A systemd service that listens for MQTT topics and conditionally executes Python scripts based on message content and conditions.

## Features

- **Topic-based script execution**: Execute different Python scripts based on MQTT topics
- **Conditional execution**: Run scripts only when specific conditions are met
- **Flexible conditions**: Support for various operators (>, <, >=, <=, ==, !=)
- **JSON payload support**: Handle both JSON and plain text MQTT messages
- **Systemd integration**: Runs as a proper system service with automatic restarts
- **Comprehensive logging**: Detailed logs for debugging and monitoring
- **Security**: Runs as dedicated system user with restricted permissions
- **Log rotation**: Automatic log file rotation and compression

## Installation

### Prerequisites

- Ubuntu 18.04 or later
- Python 3.7 or later
- MQTT broker (e.g., Mosquitto)

### Quick Installation

1. **Download the files** to your Ubuntu machine
2. **Run the installation script as root**:
   ```bash
   sudo chmod +x install.sh
   sudo ./install.sh
   ```

### Manual Installation

1. **Install dependencies**:
   ```bash
   sudo apt update
   sudo apt install python3 python3-pip
   pip3 install paho-mqtt
   ```

2. **Create service user**:
   ```bash
   sudo useradd --system --no-create-home --shell /bin/false mqtt-service
   ```

3. **Create directories**:
   ```bash
   sudo mkdir -p /usr/local/bin /etc/mqtt-service /var/log/mqtt-service
   sudo chown mqtt-service:mqtt-service /var/log/mqtt-service /etc/mqtt-service
   ```

4. **Copy files**:
   ```bash
   sudo cp mqtt_service.py /usr/local/bin/
   sudo cp config.json /etc/mqtt-service/
   sudo cp mqtt-service.service /etc/systemd/system/
   sudo chmod +x /usr/local/bin/mqtt_service.py
   ```

5. **Enable and start service**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable mqtt-service
   sudo systemctl start mqtt-service
   ```

## Configuration

### Main Configuration File

Edit `/etc/mqtt-service/config.json`:

```json
{
    "mqtt": {
        "broker": "localhost",
        "port": 1883,
        "username": "your_username",
        "password": "your_password",
        "client_id": "mqtt-service",
        "keepalive": 60
    },
    "topics": {
        "sensor/temperature": {
            "script": "/usr/local/bin/handle_temperature.py",
            "conditions": {
                "temperature": {
                    "operator": ">",
                    "threshold": 25.0
                }
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
```

### Configuration Options

#### MQTT Settings
- `broker`: MQTT broker hostname or IP
- `port`: MQTT broker port (default: 1883)
- `username`: MQTT username (optional)
- `password`: MQTT password (optional)
- `client_id`: Unique client identifier
- `keepalive`: Keepalive interval in seconds

#### Topic Configuration
Each topic can have:
- `script`: Path to Python script to execute
- `conditions`: Conditions that must be met to execute the script

#### Condition Types

**Simple equality**:
```json
"conditions": {
    "status": "offline"
}
```

**Numeric comparisons**:
```json
"conditions": {
    "temperature": {
        "operator": ">",
        "threshold": 25.0
    }
}
```

**Multiple conditions** (ALL must be true):
```json
"conditions": {
    "temperature": {
        "operator": ">",
        "threshold": 25.0
    },
    "humidity": {
        "operator": "<",
        "threshold": 60.0
    }
}
```

## Creating Python Scripts

Your Python scripts will receive MQTT data via environment variables:

- `MQTT_TOPIC`: The MQTT topic that triggered the script
- `MQTT_PAYLOAD`: The message payload (JSON string or plain text)

### Example Script

```python
#!/usr/bin/env python3
import json
import os
import logging

# Get MQTT data
topic = os.environ.get('MQTT_TOPIC')
payload = os.environ.get('MQTT_PAYLOAD')

# Parse JSON payload
data = json.loads(payload)

# Your logic here
temperature = data.get('temperature')
if temperature > 30:
    print(f"High temperature alert: {temperature}°C")
```

### Script Requirements

- Must be executable (`chmod +x script.py`)
- Should exit with code 0 on success, non-zero on failure
- Have a 30-second timeout limit
- Can access environment variables for MQTT data

## Service Management

### Start/Stop Service
```bash
sudo systemctl start mqtt-service
sudo systemctl stop mqtt-service
sudo systemctl restart mqtt-service
```

### Check Status
```bash
sudo systemctl status mqtt-service
```

### View Logs
```bash
# Real-time logs
sudo journalctl -u mqtt-service -f

# Recent logs
sudo journalctl -u mqtt-service -n 50

# Service logs
sudo tail -f /var/log/mqtt-service/mqtt-service.log
```

### Enable/Disable Auto-start
```bash
sudo systemctl enable mqtt-service   # Start on boot
sudo systemctl disable mqtt-service  # Don't start on boot
```

## Testing

### Test MQTT Messages

Using `mosquitto_pub`:

```bash
# Temperature sensor (will trigger if > 25°C)
mosquitto_pub -h localhost -t "sensor/temperature" -m '{"temperature": 30.5, "humidity": 45}'

# Device status (will trigger if status is "offline")
mosquitto_pub -h localhost -t "device/status" -m '{"device_id": "sensor01", "status": "offline"}'

# Simple message (no conditions)
mosquitto_pub -h localhost -t "system/command" -m '{"command": "restart"}'
```

### Test Script Execution

Create a test script:

```python
#!/usr/bin/env python3
import os
import json

topic = os.environ.get('MQTT_TOPIC')
payload = os.environ.get('MQTT_PAYLOAD')

print(f"Script executed for topic: {topic}")
print(f"Payload: {payload}")

# Write to a test file
with open('/tmp/mqtt_test.log', 'a') as f:
    f.write(f"{topic}: {payload}\n")
```

## Troubleshooting

### Common Issues

1. **Service won't start**:
   ```bash
   sudo systemctl status mqtt-service
   sudo journalctl -u mqtt-service -n 20
   ```

2. **Can't connect to MQTT broker**:
   - Check broker is running: `sudo systemctl status mosquitto`
   - Verify network connectivity
   - Check credentials in config.json

3. **Scripts not executing**:
   - Check script permissions: `ls -la /usr/local/bin/*.py`
   - Verify script paths in config.json
   - Check service logs for errors

4. **Permission denied**:
   - Ensure service user owns log directory: `sudo chown -R mqtt-service:mqtt-service /var/log/mqtt-service`

### Debug Mode

Enable debug logging by editing `/etc/mqtt-service/config.json`:

```json
{
    "logging": {
        "level": "DEBUG"
    }
}
```

Then restart the service:
```bash
sudo systemctl restart mqtt-service
```

## Security Considerations

- The service runs as a dedicated system user (`mqtt-service`)
- Uses systemd security features (PrivateTmp, ProtectSystem, etc.)
- Logs are rotated and compressed automatically
- Scripts have a 30-second timeout to prevent hanging
- Consider using TLS/SSL for MQTT connections in production

## File Locations

- **Service script**: `/usr/local/bin/mqtt_service.py`
- **Configuration**: `/etc/mqtt-service/config.json`
- **Logs**: `/var/log/mqtt-service/`
- **Systemd service**: `/etc/systemd/system/mqtt-service.service`
- **PID file**: `/var/run/mqtt-service.pid`

## License

This project is open source. Feel free to modify and distribute as needed. 