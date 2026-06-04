#!/bin/bash
# Backend bootstrap. Reads MONGODB_URL and PORT from /etc/durantic/backend.env
# (written by the Durantic role template), validates them, then starts the service.
set -euo pipefail

ENV_FILE="/etc/durantic/backend.env"

[ -f "$ENV_FILE" ] || { echo "ERROR: missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

[ -n "${MONGODB_URL:-}" ] || { echo "ERROR: MONGODB_URL not set in $ENV_FILE"; exit 1; }

echo "Starting backend (port ${PORT:-3000})..."
systemctl daemon-reload
systemctl enable --now backend
