# Dockerfile
FROM node:24-bookworm

# Use arguments for versioning so they can be overridden if needed
ARG HUGO_VERSION=0.163.0
ARG GO_VERSION=1.26.4

ENV PATH=$PATH:/usr/local/go/bin
ENV HUGO_CACHEDIR=/tmp/hugo_cache

# Security: Disable NPM scripts by default to block install-time malware
ENV NPM_CONFIG_IGNORE_SCRIPTS=true

# 1. Install Go
RUN curl -OL https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz

# 2. Install Hugo
RUN apt-get update && apt-get install -y git && \
    curl -L https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb -o hugo.deb && \
    apt-get install -y ./hugo.deb && \
    rm hugo.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. Setup Permissions
WORKDIR /src

# Create these folders so they are owned by 'node' before mounting
RUN mkdir -p /src/node_modules \ 
             /src/resources \
             /tmp/hugo_cache && \
    chown -R node:node /src /tmp/hugo_cache

COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node
ENTRYPOINT ["entrypoint.sh"]