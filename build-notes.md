# Firefly III build notes

## What you’re building

Firefly III is a Laravel (PHP) app + two frontend bundles:

- **v1** assets (Laravel Mix/Webpack): `resources/assets/v1`
- **v2** assets (Vite): `resources/assets/v2`

## Recommended for contribution: VS Code Dev Containers (isolated)

This repo includes a devcontainer setup that runs the app + a MariaDB database in separate containers, using:

- Compose file: `docker-compose.dev.yml`
- Devcontainer config: `.devcontainer/devcontainer.json`
- Host port: **8001** (so it won’t collide with an existing Firefly III install)
- DB storage: a dedicated Docker volume (`firefly_dev_db`) so it can’t touch your “real” database

### One-time setup

1. Install Docker.
2. In VS Code, install the **Dev Containers** extension.
3. Open this repo in VS Code → run **“Dev Containers: Reopen in Container”**.
4. Wait for the `postCreateCommand` to finish (it installs composer + npm deps and generates an `APP_KEY`).

### Initialize the dev database (first time, and whenever migrations change)

In the **container terminal**:

```bash
php artisan firefly-iii:upgrade-database 
php artisan firefly-iii:laravel-passport-keys
```

### Build frontend assets

In the **container terminal**:

```bash
npm --workspace resources/assets/v1 run production
npm --workspace resources/assets/v2 run build
```

### Run the app

In the **container terminal**:

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

Note: the devcontainer leaves the container running with `sleep infinity` so VS Code can attach; it does **not** auto-start the web server.

Visit: `http://127.0.0.1:8001`

### If dev and prod seem to “conflict” in the browser

If you run your real Firefly III on `http://localhost` (port 80) and the dev one on `http://localhost:8001`, your browser may share cookies between them (cookies are scoped to domain, not port).

Fixes:

- The devcontainer sets a unique `SESSION_COOKIE` (`firefly_dev_session`) and `APP_URL` (`http://localhost:8001`).
- If you already opened both before the change, clear cookies for `localhost` or use `127.0.0.1` for one of the two.

### About the Xdebug warning

If you see Xdebug trying (and failing) to connect to a debugger client, that’s harmless but noisy. The dev compose file disables it by default; to enable debugging, set `XDEBUG_MODE=debug` for the `app` service.

## Tests

In the **container terminal**:

```bash
composer unit-test
composer integration-test
```

## Composer quick notes

- Prefer `composer install` while contributing (reproducible via `composer.lock`).
- Avoid `composer update` unless you intend to change dependency versions.

## Local (non-Docker) option (not recommended for first run)

If you later want to run everything locally on Linux:

- PHP 8.4 + required extensions (composer will report missing ones)
- Composer v2
- Node.js + npm

Then follow the same high-level flow: `composer install`, set up `.env`, run the artisan upgrade command, build assets, and serve.

---

## Dev Container build & runtime report

This section documents how this repo is built and run inside the VS Code Dev Container setup.

### How the app is built in the dev container

There are three layers involved:

1. **Container image build** (what gets installed into the `app` image)
	 - Defined by the devcontainer Dockerfile: `.devcontainer/Dockerfile`
	 - This image provides the *toolchain* for development:
		 - PHP + required extensions (for Laravel + Firefly)
		 - Composer (PHP dependency manager)
		 - Node.js + npm (frontend build toolchain)

2. **Workspace bootstrap (post-create)** (what happens when VS Code attaches)
	 - Defined by: `.devcontainer/postCreate.sh` (invoked by the devcontainer config)
	 - This is intentionally safe to re-run.
	 - In order, it:
		 - Creates `.env` from `.env.example` if needed
		 - Writes dev-friendly `.env` values (details below)
		 - Installs backend dependencies via `composer install` (with `--no-scripts`)
		 - Installs frontend dependencies via `npm install` (npm workspaces)
		 - Builds frontend assets when they’re missing (v1 + v2)
		 - Generates an `APP_KEY`

3. **App build outputs** (what gets generated into `public/`)
	 - Backend dependencies end up in `vendor/`.
	 - Frontend bundles end up in:
		 - **v1**: `public/v1/...` (notably `public/v1/js/app.js`)
		 - **v2**: `public/build/...` (notably `public/build/manifest.json`)

Important: the devcontainer does not “compile Firefly into a distributable artifact”. It prepares a normal Laravel dev checkout (PHP sources + vendor + built assets) that you run with artisan.

### What the startup script does

The devcontainer bootstrap script is: `.devcontainer/postCreate.sh`.

Its key responsibilities:

- **Create/refresh `.env` for container use**
	- Ensures `.env` exists (copies from `.env.example` if missing).
	- Sets a few values that make the container work out-of-the-box:
		- `APP_ENV=local`
		- `APP_DEBUG=true`
		- MariaDB connection:
			- `DB_CONNECTION=mysql`
			- `DB_HOST=db`
			- `DB_PORT=3306`
			- `DB_DATABASE=firefly`
			- `DB_USERNAME=firefly`
			- `DB_PASSWORD=secret_firefly_password`

- **Avoid browser “collision” with your production Firefly**
	- Cookies are scoped to a *domain*, not a port.
	- If you run prod at `localhost` and dev at `localhost:8001`, the browser may share cookies and cause confusing auth/CSRF behavior.
	- The script sets:
		- `APP_URL=http://localhost:8001`
		- `SESSION_COOKIE=firefly_dev_session`
		- `APP_NAME="Firefly III Dev"`

- **Install dependencies**
	- `composer install --no-scripts`:
		- Installs PHP packages pinned in `composer.lock`.
		- Skips post-install artisan hooks (so you control DB migrations/keys explicitly).
	- `npm install`:
		- Installs Node deps at repo root.
		- This repo uses npm workspaces, so both `resources/assets/v1` and `resources/assets/v2` get what they need.

- **Build frontend assets (only if missing)**
	- v1: if `public/v1/js/app.js` is missing, it runs:
		- `npm --workspace resources/assets/v1 run production`
	- v2: if `public/build/manifest.json` is missing, it runs:
		- `npm --workspace resources/assets/v2 run build`

- **Generate app key**
	- Runs `php artisan key:generate --force` so encryption/session features work.

### What tools are used to run the app once the container is running

Once the dev container is up, you run Firefly with Laravel’s tooling:

- **Web server (dev)**
	- Command: `php artisan serve --host=0.0.0.0 --port=8000`
	- Reason: the container itself listens on `0.0.0.0:8000`, and Docker maps it to host port **8001**.

- **Database upgrades / migrations**
	- Command: `php artisan firefly-iii:upgrade-database --force`
	- This is the “first run” step that makes the database schema match the code.

- **Auth keys (Passport)**
	- Command: `php artisan firefly-iii:laravel-passport-keys`
	- Generates keys needed for OAuth/Passport features.

- **Frontend builds**
	- v1 build: `npm --workspace resources/assets/v1 run production`
	- v2 build: `npm --workspace resources/assets/v2 run build`

Tip: if you suspect stale caches during development, `php artisan optimize:clear` is the usual “reset caches” command in Laravel.

### How the database is used

The devcontainer stack runs MariaDB as a separate service in Compose:

- Service name: `db` (so the app uses `DB_HOST=db`)
- Data persistence: a dedicated Docker volume `firefly_dev_db`
- Isolation: this dev DB volume is separate from whatever your production stack uses

Common workflows:

- **Initialize / upgrade schema**: `php artisan firefly-iii:upgrade-database --force`
- **Reset the dev DB entirely** (destructive): bring the dev stack down and delete the volume (this is done with Docker Compose commands on the host).

### localhost vs 127.0.0.1 concerns

Both `localhost` and `127.0.0.1` typically reach your local machine, but browsers treat them as different “sites” for cookie scoping.

- If production is on `http://localhost` and dev is also on `http://localhost:8001`, cookie sharing can cause:
	- sessions “randomly” switching
	- CSRF token mismatches
	- login/logout oddities

Practical approach:

- Use **different hostnames** for prod vs dev in the browser.
	- Example: prod on `http://localhost`, dev on `http://127.0.0.1:8001`.
- This repo’s dev bootstrap also sets a unique `SESSION_COOKIE` to reduce collisions even if you do use `localhost` for both.

### What the deal is with the v1 and v2 stuff

Firefly III currently has two frontend “tracks”:

- **v1 (legacy/stable UI)**
	- Source: `resources/assets/v1`
	- Build system: Laravel Mix/Webpack
	- Output: `public/v1/...`

- **v2 (new/experimental UI)**
	- Source: `resources/assets/v2`
	- Build system: Vite
	- Output: `public/build/...` and `public/build/manifest.json`

Which UI you see is controlled by configuration (via `.env`):

- `FIREFLY_III_LAYOUT=v1` is the default in `.env.example`.
- `FIREFLY_III_LAYOUT=v2` enables the experimental view path.

If dev “feels more broken” than production, a common reason is that dev is accidentally running the **v2** layout (experimental), while production images often ship with the stable **v1** layout and prebuilt assets.

### What the dev build does to rectify v1 and v2 issues

The devcontainer setup is defensive about the most common gotchas:

- **Missing v2 manifest** (`ViteManifestNotFoundException`)
	- Fix: bootstrap auto-builds v2 if `public/build/manifest.json` is missing.

- **Missing v1 bundles** (legacy UI loads but behaves incorrectly)
	- Fix: bootstrap auto-builds v1 if `public/v1/js/app.js` is missing.

- **Browser cookie collisions with production**
	- Fix: bootstrap sets `SESSION_COOKIE=firefly_dev_session` and `APP_URL=http://localhost:8001`.

### Other things you may need to know going forward

- **The container will not auto-start the web server.**
	- This is by design: the container stays alive so VS Code can attach.
	- You start the server manually with `php artisan serve ...`.

- **When pulling new code, re-run migrations when needed.**
	- If you `git pull` changes that include migrations, run the upgrade command again.

- **Asset rebuild triggers.**
	- If you change frontend code, rebuild the relevant workspace (v1 or v2).
	- If you switch layouts, ensure the corresponding assets exist.

- **If artisan behaves strangely, clear caches.**
	- `php artisan optimize:clear` is the quickest reset.

---

## Using your changes in production (new app image, same database)

You can deploy your forked changes safely without losing data by treating the **database as the persistent state** and the **app container image as replaceable**.

### The core rule: keep your database and encryption key stable

- Your Firefly data lives in the database volume/container. Updating the app image should not touch it.
- Keep the same `DB_*` settings (host/user/password/database) so the new container points at the same database.
- Keep the same `APP_KEY` in production.
  - This is critical: Firefly/Laravel encrypts some stored values. If you change `APP_KEY`, previously-encrypted data may become unreadable.

### What “building an image” means here

This repository is the application source. To run it in production you typically build a Docker image that contains:

- The PHP application code
- The `vendor/` directory from `composer install --no-dev`
- Compiled frontend assets (v1 and/or v2) copied into `public/`

Note: this repo does not include a production Dockerfile by default (only the devcontainer image at [.devcontainer/Dockerfile](.devcontainer/Dockerfile)). That’s fine—production images are usually built from a separate Dockerfile/pipeline.

### Recommended production flow (safe upgrade)

1. Backup first
	- Take a database backup/snapshot before swapping images.

2. Build and tag your new image
	- Build from your fork/branch and tag it with something traceable (git SHA or version).
	- Push it to a registry your server can pull from (optional but common).

3. Run database upgrades using the new image
	- Before you switch traffic, run Firefly’s upgrade command against the existing DB:
	  - `php artisan firefly-iii:upgrade-database --force`
	- Do this as a one-off “job” container using the **new** image but the **same** production `.env` / environment variables.

4. Deploy the new image
	- Update your production Compose/stack to reference the new image tag.
	- Restart/recreate the app container.

5. Verify, then keep/rollback
	- If something is wrong, rollback is usually just switching the app image tag back.
	- If migrations ran and you rollback far enough, you may need to restore the DB backup as well.

### Compose pattern: preserve DB, swap app image

The safest pattern is:

- Database service uses a named volume (persistent).
- App service uses an image tag (replaceable).

When you change only the app service image tag, the DB volume stays intact.

For the “upgrade step”, run a one-off container that shares the same network/env and executes the artisan upgrade command.

### v1 vs v2 in production

- If you run `FIREFLY_III_LAYOUT=v1` in production, you only need to ensure v1 assets exist in `public/v1/...`.
- If you run `FIREFLY_III_LAYOUT=v2`, you must ensure the Vite manifest exists at `public/build/manifest.json` and that the referenced assets are present.

Practical suggestion:

- Keep production on **v1** unless you explicitly want to run the experimental v2 UI.
- If your changes touch frontend behavior, make sure your production image build includes the corresponding asset build(s).

### If you want, I can add a production Dockerfile

If you tell me your current production setup (which image you run today and whether it’s nginx+php-fpm, apache, or the official image), I can add a minimal production Dockerfile to this repo plus a short “build + push + deploy” recipe that matches it.