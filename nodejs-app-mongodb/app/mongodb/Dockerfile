# Durantic demo MongoDB boot image (Ubuntu 25.10).
# A complete-system image: built FROM the Durantic Ubuntu base, with docker.io baked in.
# The machine role renders /etc/durantic/mongodb.env at boot and enables the mongodb unit,
# which runs the official mongo:7 container bound to the mesh interface.
#
# Build:
#   docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb \
#     -f app/mongodb/Dockerfile app/mongodb
#   docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb

FROM ghcr.io/durantic/linux-ubuntu-25.10:latest

LABEL durantic.image.version="1.0" \
      durantic.image.type="complete-system" \
      durantic.image.os="ubuntu" \
      durantic.image.release="25.10" \
      durantic.image.codename="questing" \
      durantic.image.variant="nodejs-mongodb" \
      durantic.image.description="Durantic demo MongoDB — official mongo:7 via docker" \
      durantic.architecture="x86_64"

# docker.io provides the runtime for the official mongo:7 container.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY mongodb.service /etc/systemd/system/mongodb.service
COPY mongodb-bootstrap.sh /usr/local/bin/mongodb-bootstrap.sh
RUN chmod +x /usr/local/bin/mongodb-bootstrap.sh

CMD ["/bin/bash"]
