FROM alpine:latest

# Install minimal required tools
RUN apk add --no-cache bash curl docker-cli

# Add the watchdog-vpn-entrypoint.sh script
COPY watchdog-entrypoint.sh /usr/local/bin/watchdog-entrypoint.sh
RUN chmod +x /usr/local/bin/watchdog-vpn-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/watchdog-entrypoint.sh"]