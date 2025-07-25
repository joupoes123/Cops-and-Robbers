FROM spritsail/fivem:latest

# Set working directory
WORKDIR /opt/cfx-server

# Copy the cops-and-robbers resource to the resources directory
COPY . /opt/cfx-server/resources/cops-and-robbers/

# Create necessary directories for data persistence
RUN mkdir -p /opt/cfx-server/resources/cops-and-robbers/player_data && \
    mkdir -p /opt/cfx-server/resources/cops-and-robbers/backups && \
    chmod 755 /opt/cfx-server/resources/cops-and-robbers/player_data && \
    chmod 755 /opt/cfx-server/resources/cops-and-robbers/backups

# Expose FiveM server ports
EXPOSE 30120/tcp 30120/udp 40120/tcp

# Set up volumes for persistent data
VOLUME ["/config", "/txData", "/opt/cfx-server/resources/cops-and-robbers/player_data"]

# Environment variables
ENV NO_DEFAULT_CONFIG=0
ENV RCON_PASSWORD=""

# The base image already handles the startup command
