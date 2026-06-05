# Durantic demo MongoDB boot image (Ubuntu 25.10).
# A complete-system image: built FROM the Durantic Ubuntu base, with MongoDB installed
# natively. The machine role renders /etc/durantic/mongodb.env at boot and runs
# mongodb-bootstrap.sh, which writes mongod.conf (bound to the mesh IP, auth on), starts
# mongod, and creates the root user.
#
# MongoDB has no apt packages for Ubuntu 25.10 ("questing"), so we use the noble (24.04)
# repo — the latest LTS MongoDB publishes — which is ABI-compatible with the 25.10 base.
#
# Build:
#   docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb \
#     -f app/mongodb/Dockerfile app/mongodb
#   docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb

FROM ghcr.io/durantic/linux-ubuntu-25.10:latest

ARG MONGO_MAJOR=8.0

LABEL durantic.image.version="1.0" \
      durantic.image.type="complete-system" \
      durantic.image.os="ubuntu" \
      durantic.image.release="25.10" \
      durantic.image.codename="questing" \
      durantic.image.variant="nodejs-mongodb" \
      durantic.image.description="Durantic demo MongoDB — native mongodb-org server" \
      durantic.architecture="x86_64"

# Install mongodb-org from the official MongoDB apt repo (noble dist).
# systemctl is shimmed to a no-op during the build so any service hooks don't fail in the
# container (the same trick the official RKE2 image uses).
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg curl ca-certificates && \
    curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGO_MAJOR}.asc" \
      | gpg -o /usr/share/keyrings/mongodb-server-${MONGO_MAJOR}.gpg --dearmor && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-${MONGO_MAJOR}.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/${MONGO_MAJOR} multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-${MONGO_MAJOR}.list && \
    cp /usr/bin/systemctl /usr/bin/systemctl.real && \
    printf '#!/bin/sh\nexit 0\n' > /usr/bin/systemctl && chmod +x /usr/bin/systemctl && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org && \
    mv /usr/bin/systemctl.real /usr/bin/systemctl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY mongodb-bootstrap.sh /usr/local/bin/mongodb-bootstrap.sh
RUN chmod +x /usr/local/bin/mongodb-bootstrap.sh

CMD ["/bin/bash"]
