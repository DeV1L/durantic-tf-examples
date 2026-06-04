# Durantic demo backend boot image (Ubuntu 25.10).
# A complete-system image: built FROM the Durantic Ubuntu base, with Node.js + the
# backend app baked in. The machine role renders /etc/durantic/backend.env at boot and
# runs backend-bootstrap.sh, which enables the systemd service.
#
# Build:
#   docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:backend \
#     -f app/backend/Dockerfile app/backend
#   docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:backend

FROM ghcr.io/durantic/linux-ubuntu-25.10:latest

LABEL durantic.image.version="1.0" \
      durantic.image.type="complete-system" \
      durantic.image.os="ubuntu" \
      durantic.image.release="25.10" \
      durantic.image.codename="questing" \
      durantic.image.variant="nodejs-backend" \
      durantic.image.description="Durantic demo backend — PDF generator + MongoDB writer" \
      durantic.architecture="x86_64"

# Install Node.js LTS from NodeSource.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./

COPY backend.service /etc/systemd/system/backend.service
COPY backend-bootstrap.sh /usr/local/bin/backend-bootstrap.sh
RUN chmod +x /usr/local/bin/backend-bootstrap.sh

CMD ["/bin/bash"]
