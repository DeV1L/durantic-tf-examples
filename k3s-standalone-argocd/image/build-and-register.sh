#!/bin/bash
# Build, push (private), and register the baked k3s + ArgoCD boot image.
#
# One-time setup before `terraform apply` (the Terraform looks the image up via
# data.durantic_image). Re-running after the credential/image already exist will
# return 409s — that's fine, they only need to be created once.
#
# Requires:
#   DOCKER            docker binary (default "docker"; on WSL use DOCKER=docker.exe)
#   GHCR_TOKEN        ghcr.io PAT with write:packages on the dev1l account
#   DURANTIC_ENDPOINT / DURANTIC_API_TOKEN   (e.g. source ../../rke2-standalone/.env)
set -euo pipefail

IMG="ghcr.io/dev1l/durantic-k3s-argocd:latest"
DOCKER="${DOCKER:-docker}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "==> build + push (private) $IMG"
echo "$GHCR_TOKEN" | "$DOCKER" login ghcr.io -u dev1l --password-stdin
tar -czh -C "$HERE" . | "$DOCKER" build --provenance=false -t "$IMG" -
"$DOCKER" push "$IMG"

echo "==> register ghcr-dev1l registry credential"
CRED_UUID=$(curl -sk -X POST \
  -H "Authorization: Bearer $DURANTIC_API_TOKEN" -H "Content-Type: application/json" \
  "$DURANTIC_ENDPOINT/api/provisioning/registry-credentials/" \
  -d "{\"name\":\"ghcr-dev1l\",\"registry_url\":\"ghcr.io\",\"username\":\"dev1l\",\"password\":\"$GHCR_TOKEN\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('uuid',''))")
echo "    cred uuid: ${CRED_UUID:-<already exists; look it up via the API>}"

echo "==> register the boot image (private, using that credential)"
curl -sk -X POST \
  -H "Authorization: Bearer $DURANTIC_API_TOKEN" -H "Content-Type: application/json" \
  "$DURANTIC_ENDPOINT/api/provisioning/images/" \
  -d "{\"name\":\"durantic-k3s-argocd:latest\",\"docker_image_url\":\"$IMG\",\"registry_credential_uuid\":\"$CRED_UUID\",\"description\":\"Single-node k3s + ArgoCD baked boot image (no gateway)\"}"
echo
echo "done — now run: terraform apply"
