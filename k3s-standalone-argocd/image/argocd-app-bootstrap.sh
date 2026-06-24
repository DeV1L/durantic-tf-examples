#!/bin/bash
# Baked into the image. Waits for ArgoCD (installed via the baked HelmChart) and
# creates the app-of-apps Application from /etc/durantic/argocd.env (written by the
# role). The repo is public, so no repo credentials are needed.
set -euo pipefail
ENV_FILE="/etc/durantic/argocd.env"
[ -f "$ENV_FILE" ] || { echo "No $ENV_FILE - skipping ArgoCD bootstrap"; exit 0; }
# shellcheck disable=SC1090
source "$ENV_FILE"
[ -n "${ARGOCD_REPO_URL:-}" ] || { echo "ARGOCD_REPO_URL unset - skipping"; exit 0; }
ARGOCD_TARGET_REVISION="${ARGOCD_TARGET_REVISION:-main}"
ARGOCD_APP_PATH="${ARGOCD_APP_PATH:-.}"

echo "Waiting for ArgoCD CRDs..."
for i in $(seq 1 60); do
  k3s kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
  [ "$i" = "60" ] && { echo "ERROR: ArgoCD CRDs not ready after 10m"; exit 1; }
  sleep 10
done
k3s kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true

echo "Creating app-of-apps Application -> ${ARGOCD_REPO_URL}@${ARGOCD_TARGET_REVISION}/${ARGOCD_APP_PATH}"
k3s kubectl apply -f - <<APP
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "${ARGOCD_REPO_URL}"
    targetRevision: "${ARGOCD_TARGET_REVISION}"
    path: "${ARGOCD_APP_PATH}"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
APP
echo "ArgoCD app-of-apps created."
