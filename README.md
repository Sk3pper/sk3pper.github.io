# Personal Site and Blog

This repository contains the source code for my personal site and blog, which is deployed using GitHub Pages. You can visit the live site [here](https://sk3pper.github.io/#).

## Built With

- **Hugo**: A fast and flexible static site generator.
- **Toha Theme**: A Hugo theme designed for personal websites and blogs. You can find more information about the theme [here](https://github.com/hugo-toha/toha).

---

## 🛡️ Security & Architecture Decisions

This project uses a containerized development environment to mitigate specific security risks associated with the modern web supply chain.

### Why Docker?

Running `npm install` directly on a host machine allows third-party packages to execute arbitrary code via `preinstall` or `postinstall` scripts. This setup isolates those processes within a container.

### Security Measures Implemented

1. **Supply Chain Hardening**:
- **`npm ci` vs `npm install`**: I prioritize `npm ci` (Clean Install) to strictly respect the `package-lock.json`. This prevents the accidental installation of compromised "newer" versions of dependencies.
- **`NPM_CONFIG_IGNORE_SCRIPTS=true`**: I explicitly disable package scripts globally. This blocks the most common vector for NPM malware (malicious scripts running during installation).


2. **Pinned Dependencies**:
* The OS is pinned to ensure system library compatibility with modern Hugo versions.
* Hugo and Go versions are explicitly defined in the `Dockerfile` arguments.


3. **Least Privilege (User `node`)**:
* **Security**: By default, Docker containers run as `root`. I explicitly switch to the unprivileged `node` user. If a malicious NPM package manages to execute code, it is confined to the `node` user's permissions, preventing it from installing system packages or modifying the container's core filesystem.
* **Host Permissions**: On Linux systems, files created by a `root` container are owned by `root` on the host machine, making them impossible to delete without `sudo`. Running as `node` (UID 1000) ensures that files created in shared volumes (like `node_modules`) are owned by the local user, keeping the development environment clean.

---

## 💻 Local Development Setup

The local environment setup is designed to solve common issues with Hugo modules, file permissions on Linux, and build performance.

### Key Configuration Details

#### 1. Solving the Permission "Lock" (`--renderToMemory`)

A common issue when running Docker on Linux is the file permission conflict between the container user (`root` or `node`) and the host user.

* **The Problem:** Even when running as `node`, Hugo tries to copy read-only files from the Go Module cache to the build folder. This often causes "Permission Denied" crashes during rebuilds because the process cannot overwrite its own read-only files.
* **The Solution:** I use `hugo server --renderToMemory`. This forces Hugo to serve the site entirely from RAM. It bypasses the file system entirely, eliminating permission conflicts and increasing build speed.

#### 2. Performance Caching (`hugo_cache`)

I use a persistent Docker volume (`hugo_cache`) mapped to `/tmp/hugo_cache`.

* **Purpose:** The Toha theme is a Go Module that requires downloading and processing (resizing/cropping) images.
* **Benefit:** Persisting this cache prevents Hugo from re-downloading the theme and re-processing all images every time the container restarts, significantly speeding up boot times.

#### 3. Entrypoint Logic

The `entrypoint.sh` script acts as a safeguard:

* It dynamically merges the theme's dependencies with `hugo mod npm pack`.
* It checks for a lockfile to determine whether to run a secure install (`npm ci`) or a generation install (`npm install`).

### How to Run

To start the development server:

```bash
# 1. Build the image
docker build -t toha-dev .

# 2. Clean up any old "poisoned" volumes (Crucial if permissions break)
docker compose down --volumes

# 3. Start the server
docker compose up --build

```

The local site will be available at `http://localhost:1313`.