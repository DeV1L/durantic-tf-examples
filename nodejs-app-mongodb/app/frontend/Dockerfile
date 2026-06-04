# Durantic demo frontend boot image (Ubuntu 25.10).
# A complete-system image: built FROM the Durantic Ubuntu base, with Node.js + the
# frontend app baked in. The machine role renders /etc/durantic/frontend.env at boot and
# runs frontend-bootstrap.sh, which enables the systemd service.
#
# Build:
#   docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:frontend \
#     -f app/frontend/Dockerfile app/frontend
#   docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:frontend

FROM ghcr.io/durantic/linux-ubuntu-25.10:latest

LABEL durantic.image.version="1.0" \
      durantic.image.type="complete-system" \
      durantic.image.os="ubuntu" \
      durantic.image.release="25.10" \
      durantic.image.codename="questing" \
      durantic.image.variant="nodejs-frontend" \
      durantic.image.description="Durantic demo frontend — UI + /api proxy" \
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
COPY public ./public

COPY frontend.service /etc/systemd/system/frontend.service
COPY frontend-bootstrap.sh /usr/local/bin/frontend-bootstrap.sh
RUN chmod +x /usr/local/bin/frontend-bootstrap.sh

CMD ["/bin/bash"]
