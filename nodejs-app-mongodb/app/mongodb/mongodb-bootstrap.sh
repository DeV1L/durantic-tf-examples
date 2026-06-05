#!/bin/bash
# MongoDB bootstrap. Reads MONGO_ROOT_PASSWORD and MESH_IP from /etc/durantic/mongodb.env
# (written by the Durantic role template), then:
#   1. waits for the mesh IP to be configured,
#   2. writes /etc/mongod.conf bound to localhost + the mesh IP, with auth enabled,
#   3. starts mongod,
#   4. creates the root user (idempotent, via the localhost exception on first boot).
set -euo pipefail

ENV_FILE="/etc/durantic/mongodb.env"

[ -f "$ENV_FILE" ] || { echo "ERROR: missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

[ -n "${MONGO_ROOT_PASSWORD:-}" ] || { echo "ERROR: MONGO_ROOT_PASSWORD not set in $ENV_FILE"; exit 1; }
[ -n "${MESH_IP:-}" ]            || { echo "ERROR: MESH_IP not set in $ENV_FILE"; exit 1; }

# 1. Wait until the mesh IP is actually configured on an interface, so mongod can bind it.
echo "Waiting for mesh IP ${MESH_IP} to appear..."
for round in $(seq 1 60); do
  if ip -4 addr show | grep -qw "$MESH_IP"; then echo "  -> ${MESH_IP} is up"; break; fi
  if [ "$round" -eq 60 ]; then echo "ERROR: ${MESH_IP} not configured after 2 minutes"; exit 1; fi
  sleep 2
done

# 2. mongod config: reachable on the mesh (and localhost), authentication required.
cat > /etc/mongod.conf <<EOF
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
net:
  port: 27017
  bindIp: 127.0.0.1,${MESH_IP}
security:
  authorization: enabled
EOF

# 3. Start mongod.
echo "Starting mongod..."
systemctl enable --now mongod

# 4. Create the root user once mongod is accepting connections.
echo "Waiting for mongod to accept connections..."
for round in $(seq 1 30); do
  if mongosh --quiet --host 127.0.0.1 --eval 'db.runCommand({ ping: 1 })' >/dev/null 2>&1; then break; fi
  if [ "$round" -eq 30 ]; then echo "ERROR: mongod not responding after 60s"; exit 1; fi
  sleep 2
done

if mongosh --quiet "mongodb://root:${MONGO_ROOT_PASSWORD}@127.0.0.1:27017/admin" \
     --eval 'db.runCommand({ ping: 1 })' >/dev/null 2>&1; then
  echo "Root user already configured."
else
  echo "Creating root user (localhost exception)..."
  mongosh --quiet --host 127.0.0.1 admin --eval "
    db.createUser({
      user: 'root',
      pwd: '${MONGO_ROOT_PASSWORD}',
      roles: [ { role: 'root', db: 'admin' } ]
    })
  "
fi

echo "MongoDB ready on ${MESH_IP}:27017"
