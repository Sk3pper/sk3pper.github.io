#!/bin/bash
set -e

# --- STEP A: HUGO MODULES ---
echo "-------------------------------------------------------"
echo "STEP 1: Syncing Hugo Modules"
echo "Description: Checking go.mod and downloading theme dependencies..."
echo "-------------------------------------------------------"
hugo mod tidy

# --- STEP B: NODE MODULES ---
echo ""
echo "-------------------------------------------------------"
echo "STEP 2: Preparing Node environment"
echo "Description: Extracting package.json from modules and installing JS dependencies..."
echo "-------------------------------------------------------"
hugo mod npm pack
npm install

echo ""
echo "-------------------------------------------------------"
echo "STEP 3: Securing Dependencies"
echo "Description: Running 'npm audit fix --force' to resolve vulnerabilities..."
echo "-------------------------------------------------------"
npm audit fix

# --- STEP C: RUN SERVER ---
echo ""
echo "-------------------------------------------------------"
echo "STEP 4: Launching Development Server"
echo "Description: Starting Hugo with Live Reload on port 1313..."
echo "-------------------------------------------------------"
exec hugo server -w --bind 0.0.0.0 --port 1313 --disableFastRender