# Production build (custom image from this repo)

This repo can be built into a production Docker image that is compatible with the upstream `fireflyiii/core:latest` runtime.

It uses a multi-stage build:
- PHP deps: `composer install --no-dev --no-scripts`
- Frontend assets:
  - v1 (Laravel Mix) -> `public/v1/js/...`
  - v2 (Vite) -> `public/build/...` + `public/mix-manifest.json`

## One-time notes

- Your MariaDB data stays unchanged as long as you keep using the same named volume (`firefly_iii_db`).
- Stop the existing containers before replacing them, otherwise container-name and port collisions will happen.

## Build the image

From the repo root:

`docker build -f Dockerfile.production -t fireflyiii/core:custom .`

## Run with Docker Compose

This repo includes a compose file that mirrors the “official” production compose layout:

`docker compose -f docker-compose.production.yml up -d --build`

### Upgrading / database migrations

The upstream runtime image runs various Laravel automation scripts on startup.
If you ever need to run upgrades manually:

`docker compose -f docker-compose.production.yml exec -T app php artisan firefly-iii:upgrade-database --force`

## Rollback

If you want to roll back to the official image:
- change the `app` service back to `image: fireflyiii/core:latest`
- run `docker compose up -d`

The DB volume remains intact.
