# Durantic single-node k3s + ArgoCD boot image (standalone, NO gateway).
#
# FROM the official Ubuntu base, bakes in: the k3s binary + systemd unit (offline,
# not started/enabled), the ArgoCD HelmChart auto-deploy manifest, and two bootstrap
# scripts. The machine role's cloud-init then only WRITES config and STARTS k3s — it
# installs no binaries at runtime.
#
# Build + push (public):
#   tar -czh -C image . | docker build -t ghcr.io/dev1l/durantic-k3s-argocd:latest -
#   docker push ghcr.io/dev1l/durantic-k3s-argocd:latest
FROM ghcr.io/durantic/linux-ubuntu-25.10:latest

ARG K3S_VERSION=v1.34.3+k3s3

LABEL durantic.image.version="1.0" \
      durantic.image.type="complete-system" \
      durantic.image.os="ubuntu" \
      durantic.image.release="25.10" \
      durantic.image.codename="questing" \
      durantic.image.variant="k3s-argocd" \
      durantic.image.description="Single-node k3s + ArgoCD (standalone, no gateway)" \
      durantic.architecture="x86_64"

# Bake the k3s binary + systemd unit (offline). SKIP_START/SKIP_ENABLE so the install
# only lays down files; the role's cloud-init starts it at boot. e2fsprogs provides
# mkfs.ext4 for formatting the data disk on first boot.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y e2fsprogs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${K3S_VERSION}" \
      INSTALL_K3S_SKIP_START=true \
      INSTALL_K3S_SKIP_ENABLE=true \
      INSTALL_K3S_EXEC="server" \
      sh -

# ArgoCD auto-deploy: k3s applies manifests in this dir on first start.
COPY argocd.yaml /var/lib/rancher/k3s/server/manifests/argocd.yaml

# Bootstrap scripts (read the config the role writes at boot).
COPY k3s-public-api.sh argocd-app-bootstrap.sh mount-data-disk.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/k3s-public-api.sh /usr/local/bin/argocd-app-bootstrap.sh /usr/local/bin/mount-data-disk.sh

CMD ["/bin/bash"]
