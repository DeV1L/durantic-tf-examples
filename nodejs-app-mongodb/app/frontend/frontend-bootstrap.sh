#!/bin/bash
# Frontend bootstrap. Reads BACKEND_URL and PORT from /etc/durantic/frontend.env
# (written by the Durantic role template), validates them, then starts the service.
set -euo pipefail

ENV_FILE="/etc/durantic/frontend.env"

[ -f "$ENV_FILE" ] || { echo "ERROR: missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

[ -n "${BACKEND_URL:-}" ] || { echo "ERROR: BACKEND_URL not set in $ENV_FILE"; exit 1; }

echo "Starting frontend (port ${PORT:-80}) -> backend ${BACKEND_URL}..."
systemctl daemon-reload
systemctl enable --now frontend
