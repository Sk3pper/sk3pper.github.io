FROM node:22-bullseye

# Update to the version required by Toha v4.12.0+
ENV HUGO_VERSION=0.146.0
ENV GO_VERSION=1.25.5
ENV PATH=$PATH:/usr/local/go/bin
ENV HUGO_CACHEDIR=/tmp/hugo_cache

# Silence npm noise
ENV NPM_CONFIG_FUND=false
ENV NPM_CONFIG_UPDATE_NOTIFIER=false

# 1. Install Go
RUN curl -OL https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz

# 2. Install Hugo Extended 0.146.0
RUN apt-get update && apt-get install -y git && \
    curl -L https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb -o hugo.deb && \
    apt-get install -y ./hugo.deb && \
    rm hugo.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. Update NPM
RUN npm install -g npm@latest

# 4. Setup Permissions
WORKDIR /src
RUN mkdir -p /src/node_modules /tmp/hugo_cache && \
    chown -R node:node /src /tmp/hugo_cache

COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node
ENTRYPOINT ["entrypoint.sh"]