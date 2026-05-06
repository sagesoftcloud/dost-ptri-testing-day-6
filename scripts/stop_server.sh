#!/bin/bash
# Stop the running application (if any)
echo "Stopping application..."
pkill -f "python app.py" || true
