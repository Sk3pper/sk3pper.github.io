---
title: "Building a Secure and Clean Local Hugo Environment with Docker"
date: 2025-12-21 
author: 
  name: Sk3pper
hero: /images/secure-docker-hugo.png
description: "A journey through dependency hell, Linux permissions, and supply chain security to build a secure local dev setup."
theme: Toha

menu:
  sidebar:
    name: Building a Secure Local Hugo Environment
    identifier: secure-hugo-docker
    parent: dev-sec-ops
    weight: 10
---

{{< alert type="info" >}}
This article details the specific configuration I use for this site (built with Hugo and the Toha theme). You can find the complete source code for this setup at the end of the post.
{{< /alert >}}

# 1. Introduction

## 1.1 The Goal

I run this site using **Hugo** and the **Toha** theme. While Hugo is a static binary, modern themes like Toha rely heavily on Go Modules and NPM packages for assets. Initially, I ran everything locally on my machine, but this polluted my system and left me **worrying about supply chain attacks**.

I wanted a **clean, isolated, and secure** development environment that:

1. **Secures the Supply Chain:** Protects against malicious NPM packages.
2. **Runs as Non-Root:** Follows the principle of least privilege.
3. **Solves "Dependency Hell":** Pins exact versions of Hugo, Go, and Node.
4. **Fixes Permission Issues:** Solves the classic Docker-on-Linux volume permission headaches.

# 2. Security Decisions

Before writing a single line of code, I had to address the security risks inherent in modern web development.

## 2.1 The NPM Supply Chain Risk

> Recent weeks have shown that the NPM ecosystem is a prime target for supply chain attacks. As detailed in the **[Resources & Further Reading](https://www.google.com/search?q=%237-resources--further-reading)** section below, a common vector in the 2025 campaigns has been malicious code hidden in `preinstall` or `postinstall` scripts that run automatically when you type `npm install`.

To mitigate this, I made two major decisions for the Docker image:

1. **Disable Scripts Globally:** I set `ENV NPM_CONFIG_IGNORE_SCRIPTS=true`. This blocks packages from executing arbitrary commands during installation.
2. **Strict Install (`npm ci`):** I prefer `npm ci` over `npm install`. The `ci` command strictly adheres to the `package-lock.json`. It prevents the accidental installation of a "newer" (potentially compromised) version of a dependency that hasn't been vetted yet.

## 2.2 Least Privilege (User `node`)

By default, Docker containers run as `root`. If a malicious package *did* manage to execute, it would have root access inside the container (and potentially the host via volume escapes).

I explicitly switch to the `USER node` (UID 1000). This provides two benefits:

1. **Security:** Malicious code is confined to a low-privileged user.
2. **Hygiene:** Files created in shared volumes (like `node_modules`) are owned by my local user (UID 1000), not root, keeping my local filesystem clean.

# 3. The Challenge: Permission Locks & Version Hell

Implementing `USER node` on Linux introduced a new problem: **File Permissions**.

## 3.1 The "Permission Denied" Loop

When Hugo generates a site, it writes files to a `public/` folder.

- If I mounted a volume to `/src/public` to see the files, and the container ran as `node`, it often couldn't overwrite files created during a previous run (especially if Docker initialized the volume as root).
- Even worse, Hugo copies files from the Go Module cache, which are often marked **Read-Only**. When Hugo tried to rebuild the site during a "Live Reload," it crashed because it couldn't overwrite its own read-only `sitemap.xml`.

## 3.2 The Panic: `nil walk context`

I also faced a crash in Hugo v0.146.0: `panic: nil walk context`. This occurred during fast-renders when Hugo attempted to process file changes but hit those permission locks or internal concurrency bugs.

Downgrading wasn't an option because the Toha theme (v4.12) required features found only in the latest Hugo versions. I was stuck between a buggy new version and an incompatible old version.

# 4. The Solution: In-Memory Rendering

The breakthrough came when I realized that for a **local development environment**, I don't actually need the physical HTML files on my disk. I just need the localhost server to work.

I switched to using **In-Memory Rendering**:

```bash
hugo server --renderToMemory
```

This solved everything:

1. **No Permissions Issues:** The site is built entirely in RAM. The `node` user has full access to the container's memory, bypassing the complex Linux file system permissions.
2. **Speed:** Building in RAM is significantly faster than writing thousands of small files to a Docker volume.
3. **Stability:** It bypassed the specific file-locking bugs causing the `nil walk context` panic in Hugo v0.146.0.

# 5. The Implementation

Here is the final configuration that powers my local development.

## 5.1 Dockerfile

This file handles the security hardening and dependency pinning. Note the use of `bookworm` (Debian 12) to ensure the system `GLIBC` libraries are compatible with the latest Hugo binary.

```dockerfile
FROM node:22-bookworm

# Use arguments for versioning so they can be overridden if needed
ARG HUGO_VERSION=0.146.0
ARG GO_VERSION=1.25.5

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
             /src/resources && \
    chown -R node:node /src

COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER node
ENTRYPOINT ["entrypoint.sh"]

```

## 5.2 docker-compose.yml

I use a named volume `hugo_cache` mapped to `/tmp/hugo_cache`. This persists the downloaded Go modules and processed images. Without this, Hugo would re-download the theme and re-process every image on every restart, which is incredibly slow.

```yaml
services:
  hugo:
    build: .
    ports:
      - "1313:1313"
    environment:
      - HUGO_ENVIRONMENT=development
    volumes:
      - .:/src
      # Isolating these keeps the host clean and permissions managed by Docker
      - /src/node_modules
      - /src/resources
      # Performance: Persist the cache to avoid re-downloading modules
      - hugo_cache:/tmp/hugo_cache

volumes:
  hugo_cache:

```

## 5.3 entrypoint.sh

This script handles the logic of merging the theme dependencies and deciding how to install them.

```bash
#!/bin/bash
set -e

# --- STEP 1: GO MODULES ---
echo "STEP 1: Syncing Hugo/Go Modules..."
hugo mod tidy

# --- STEP 2: GENERATE PACKAGE.JSON ---
echo "STEP 2: Merging Theme Dependencies..."
# Extracting package.json from modules and installing JS dependencies
hugo mod npm pack

# --- STEP 3: INSTALL DEPENDENCIES ---
echo "STEP 3: Installing Node Modules..."

if [ -f "package-lock.json" ]; then
    echo "  > Lockfile found. Using 'npm ci' for reproducible, secure build."
    npm ci
else
    echo "  ! WARNING: No lockfile found."
    echo "  > Running 'npm install' to generate one. PLEASE COMMIT 'package-lock.json'!"
    npm install
fi

# --- STEP 4: RUN SERVER ---
# Ensure no stale temp files exist
rm -rf /tmp/public

echo "STEP 4: Launching Hugo Server..."
# --renderToMemory avoids all Linux file permission issues and boosts speed
exec hugo server -w --bind 0.0.0.0 --port 1313 --disableFastRender --renderToMemory

```

# 6. Conclusion

By combining `USER node`, `npm ci`, and `renderToMemory`, I now have a local environment that is:

- **Secure:** Isolated from my host and protected against NPM scripts.
- **Fast:** Builds in RAM and caches expensive image processing.
- **Stable:** Pinned versions prevent random breakages.

If you are struggling with Hugo permissions on Docker, try switching to memory rendering—it’s a game changer.

# 7. Resources & Further Reading
If you want to dig deeper into the specific attacks that motivated this architecture, here are the technical analyses and incident reports from the recent waves of NPM supply chain compromises.

**Recent Incidents (2025)**
- [The "Shai-Hulud" Worm Analysis (Unit 42)](https://unit42.paloaltonetworks.com/npm-supply-chain-attack/)
- [AWS Security: Responding to Recent NPM Threats](https://aws.amazon.com/blogs/security/what-aws-security-learned-from-responding-to-recent-npm-supply-chain-threat-campaigns/)
- [GitLab: Widespread NPM Supply Chain Attack](https://about.gitlab.com/blog/gitlab-discovers-widespread-npm-supply-chain-attack/)
- [The "Chalk" & "Debug" Compromise (Qualys)](https://blog.qualys.com/vulnerabilities-threat-research/2025/09/10/when-dependencies-turn-dangerous-responding-to-the-npm-supply-chain-attack)

**Hardening Guides**
- [Malicious Code Hidden in NPM Packages (Cycode)](https://cycode.com/blog/malicious-code-hidden-in-npm-packages/)
- [NPM Security Best Practices (GitHub)](https://github.com/bodadotsh/npm-security-best-practices)
