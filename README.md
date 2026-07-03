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
docker compose up --build hugo
```

The local site will be available at `http://localhost:1313`

---

## 🔄 Updating Dependencies

Dependency updates run inside the same container as the dev server. The commands
below use `--entrypoint bash` to bypass the container's startup script
(`entrypoint.sh`), so no dev server is launched and only the requested commands
run. Thanks to the bind mount (`.:/src`), the regenerated lockfiles
(`go.mod`, `go.sum`, `package.json`, `package-lock.json`) are written back to
your host, ready to be committed.


### Update the Toha Theme (Go module + npm lockfile, all in one)

Updating the theme changes more than just the Go module. The theme also declares
npm dependencies, so a theme update touches **two sets of lockfiles**:

- `go.mod` / `go.sum` — the theme version itself
- `package.json` / `package-lock.json` — the npm dependencies the theme declares

If you update only the Go module, the npm lockfile is left out of sync and the
next `npm ci` in the dev service will fail. Run the full chain in one go:

```bash
# Update to the latest release
docker compose run --rm --entrypoint bash hugo -c \
  "hugo mod get -u github.com/hugo-toha/toha/v4 && hugo mod tidy && hugo mod npm pack && rm -f package-lock.json && npm install"

# Or pin to a specific version (replace v4.X.X with the target release)
docker compose run --rm --entrypoint bash hugo -c \
  "hugo mod get github.com/hugo-toha/toha/v4@v4.X.X && hugo mod tidy && hugo mod npm pack && rm -f package-lock.json && npm install"
```

> The commands above already regenerate the npm lockfile: no separate npm step
> is needed after a theme update.

> **Note:** The theme is currently this site's only Go module dependency. If more
> Hugo modules are added later, `hugo mod get -u` (without arguments) updates all
> of them at once — followed by the same `hugo mod tidy && hugo mod npm pack &&
> rm -f package-lock.json && npm install` chain.

#### Update Hugo version if it is necessary

Hugo is pinned in the `Dockerfile`, so the fix is to bump it there and rebuild the image:

1. Edit the `Dockerfile` and update the argument:
   ```dockerfile
   ARG HUGO_VERSION=X.YYY.Z
   ```
2. Rebuild the image:
   ```bash
   docker compose build --no-cache
   ```
3. Re-run the site to confirm the warning is gone.

Check the [theme's release notes](https://github.com/hugo-toha/toha/releases) before upgrading — they call out breaking changes, renamed shortcodes, and deprecated configuration keys.




### Refresh NPM Packages Only (audit or patch without a theme update)

Use this when you want to refresh npm dependencies **without changing the theme
version** (e.g. to pick up patched transitive dependencies or run an audit).
If you just updated the theme, this step already happened.

The theme declares its npm dependencies in a manifest that `hugo mod npm pack`
merges into your `package.json`. Running `npm install` afterwards updates
`package-lock.json` on your host:

```bash
# Regenerate package.json from the theme and refresh the lockfile
docker compose run --rm --entrypoint bash hugo -c "hugo mod npm pack && npm install"

# Optionally apply safe vulnerability fixes (semver-compatible only, no breaking changes)
docker compose run --rm --entrypoint bash hugo -c "hugo mod npm pack && npm audit fix"

# Check what's still remaining
docker compose run --rm --entrypoint bash hugo -c "hugo mod npm pack && npm audit"
```

`npm ci` in the main service will use the new lockfile on the next start.

`npm audit fix` (without `--force`) is safe to run — it only applies semver-compatible patches. If vulnerabilities remain after running it, they are pinned by the theme's transitive dependency tree and require a breaking major version bump to fix. Avoid `npm audit fix --force` as it allows major version upgrades that can break the theme's build pipeline.

### After Any Update

1. Verify the site still works:
   ```bash
   docker compose up --build hugo
   ```
2. Re-run the audit to check if vulnerabilities were resolved:
   ```bash
   docker compose run --rm --entrypoint bash hugo -c "hugo mod npm pack && npm audit"
   ```
3. Commit the updated files and if you also bumped Hugo/Go/Node, include the `Dockerfile` and
   `.github/workflows/*.yaml` (CI pins the same versions).