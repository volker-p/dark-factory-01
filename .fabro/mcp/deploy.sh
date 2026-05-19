#!/bin/bash
# Deploy OpenProject MCP server on the fabro host.
# Run this as root (or with sudo) on fabro.uawg.xyz.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_KEY="${OPENPROJECT_API_KEY:-a8047219aed9fd7c593ae4713379404f781ae1511e87e91401b4ebd85ad9d38b}"

echo "==> Installing Python mcp package"
pip3 install --quiet "mcp>=1.0"

echo "==> Copying server script"
mkdir -p /opt/fabro-mcp
cp "$SCRIPT_DIR/openproject.py" /opt/fabro-mcp/openproject.py
chmod +x /opt/fabro-mcp/openproject.py

echo "==> Writing secrets file"
mkdir -p /etc/fabro-mcp
cat > /etc/fabro-mcp/secrets.env <<EOF
OPENPROJECT_API_KEY=${API_KEY}
EOF
chmod 600 /etc/fabro-mcp/secrets.env

echo "==> Installing systemd service"
cp "$SCRIPT_DIR/openproject-mcp.service" /etc/systemd/system/openproject-mcp.service
systemctl daemon-reload
systemctl enable openproject-mcp
systemctl restart openproject-mcp

echo "==> Waiting for service to start"
sleep 2
systemctl status openproject-mcp --no-pager

echo "==> Smoke test"
curl -sf http://localhost:8090/mcp && echo "OK" || echo "WARNING: smoke test failed — check systemctl logs"
