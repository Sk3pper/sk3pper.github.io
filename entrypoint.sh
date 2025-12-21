#!/bin/bash
set -e

# --- STEP 1: GO MODULES ---
echo "STEP 1: Syncing Hugo/Go Modules..."
# Checking go.mod and downloading theme dependencies
hugo mod tidy

# --- STEP 2: GENERATE PACKAGE.JSON ---
echo "STEP 2: Merging Theme Dependencies..."
# Extracting package.json from modules and installing JS dependencies
hugo mod npm pack

# --- STEP 3: INSTALL DEPENDENCIES ---
echo "STEP 3: Installing Node Modules..."

if [ -f "package-lock.json" ]; then
    echo "  > Lockfile found. Using 'npm ci' for reproducible, secure build."
    # npm ci is faster and stricter. It ignores package.json if lockfile exists.
    # We allow scripts ONLY if you explicitly set a flag, otherwise they are blocked by Dockerfile ENV
    npm ci
else
    echo "  ! WARNING: No lockfile found."
    echo "  > Running 'npm install' to generate one. PLEASE COMMIT 'package-lock.json'!"
    npm install
fi

# --- STEP 4: RUN SERVER ---
rm -rf /tmp/public

echo "STEP 4: Launching Hugo Server..."
# Bind to 0.0.0.0 is correct for Docker
# We build to /tmp/public so we never conflict with host permissions or volume locks
exec hugo server -w --bind 0.0.0.0 --port 1313 --disableFastRender --renderToMemory