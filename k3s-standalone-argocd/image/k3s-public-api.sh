#!/bin/bash
# Baked into the image. Auto-detect public IPs and enable public k3s API access
# (bind 0.0.0.0 + add the public IP to tls-san). Reads the config the role writes.
CONFIG="/etc/rancher/k3s/config.yaml"
[ -f "$CONFIG" ] || { echo "No k3s config at $CONFIG"; exit 0; }
PUBLIC_IPS=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -v -E '^(10[.]|172[.](1[6-9]|2[0-9]|3[01])[.]|192[.]168[.])' || true)
if [ -z "$PUBLIC_IPS" ]; then
  echo "No public IPs detected - API bound to mesh only"
  exit 0
fi
sed -i 's/^bind-address: .*/bind-address: "0.0.0.0"/' "$CONFIG"
for ip in $PUBLIC_IPS; do
  grep -q "$ip" "$CONFIG" || sed -i "/^tls-san:/a\\  - \"$ip\"" "$CONFIG"
done
echo "Public API enabled for: $PUBLIC_IPS"
