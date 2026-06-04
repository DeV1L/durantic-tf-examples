#!/bin/bash
# MongoDB bootstrap. Reads MONGO_ROOT_PASSWORD and MESH_IP from /etc/durantic/mongodb.env
# (written by the Durantic role template), then runs the official mongo:7 container bound
# to the mesh interface with a persistent data volume.
#
# Running MongoDB as the official container (rather than a native 25.10 package) keeps the
# demo simple and reliable; docker.io is baked into this boot image.
set -euo pipefail

ENV_FILE="/etc/durantic/mongodb.env"
DATA_DIR="/var/lib/mongo-data"
IMAGE="mongo:7"

[ -f "$ENV_FILE" ] || { echo "ERROR: missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

[ -n "${MONGO_ROOT_PASSWORD:-}" ] || { echo "ERROR: MONGO_ROOT_PASSWORD not set in $ENV_FILE"; exit 1; }
[ -n "${MESH_IP:-}" ]            || { echo "ERROR: MESH_IP not set in $ENV_FILE"; exit 1; }

systemctl enable --now docker
mkdir -p "$DATA_DIR"

# Recreate the container so a re-provision picks up new config.
docker rm -f mongo 2>/dev/null || true

# Bind 27017 to the mesh IP only — reachable by the backend over the Durantic mesh, not
# on the machine's public interface.
docker run -d --name mongo --restart always \
  -p "${MESH_IP}:27017:27017" \
  -v "${DATA_DIR}:/data/db" \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD}" \
  "$IMAGE"

echo "MongoDB started on ${MESH_IP}:27017"
