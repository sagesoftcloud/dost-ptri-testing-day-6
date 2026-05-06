#!/bin/bash
# Start the application in the background
echo "Starting application..."
cd /opt/dost-ptri-app
nohup python app.py > /var/log/dost-ptri-app.log 2>&1 &
