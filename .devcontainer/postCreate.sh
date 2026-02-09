#!/usr/bin/env bash
set -euo pipefail

# Keep this script safe to re-run.
if [[ ! -f .env ]]; then
  cp .env.example .env
fi

# Minimal env adjustments for a dev container setup.
# (We keep secrets as the repo's defaults; this is only for local dev.)
sed -i 's/^APP_ENV=.*/APP_ENV=local/' .env || true
sed -i 's/^APP_DEBUG=.*/APP_DEBUG=true/' .env || true
sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env || true
sed -i 's/^DB_HOST=.*/DB_HOST=db/' .env || true
sed -i 's/^DB_PORT=.*/DB_PORT=3306/' .env || true
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=firefly/' .env || true
sed -i 's/^DB_USERNAME=.*/DB_USERNAME=firefly/' .env || true
sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=secret_firefly_password/' .env || true

# Prevent cookie/session collisions with an existing Firefly III running on the same host.
# Cookies are scoped to domain, not port, so localhost:80 and localhost:8001 can otherwise clash.
if grep -q '^APP_NAME=' .env; then
  sed -i 's/^APP_NAME=.*/APP_NAME="Firefly III Dev"/' .env || true
else
  printf '\nAPP_NAME="Firefly III Dev"\n' >> .env
fi

if grep -q '^APP_URL=' .env; then
  sed -i 's#^APP_URL=.*#APP_URL=http://localhost:8001#' .env || true
else
  printf 'APP_URL=http://localhost:8001\n' >> .env
fi

if grep -q '^SESSION_COOKIE=' .env; then
  sed -i 's/^SESSION_COOKIE=.*/SESSION_COOKIE=firefly_dev_session/' .env || true
else
  printf 'SESSION_COOKIE=firefly_dev_session\n' >> .env
fi

# Install PHP deps without running Firefly's post-install artisan scripts yet.
composer install --no-interaction --prefer-dist --no-progress --no-scripts

# Node deps are managed via npm workspaces (root package.json).
npm install

# Firefly III (v1) uses Laravel Mix/Webpack and expects compiled bundles in public/v1/js.
# Build them automatically if they're missing so the legacy UI works out-of-the-box.
if [[ ! -f public/v1/js/app.js ]]; then
  npm --workspace resources/assets/v1 run production
fi

# Firefly III (v2) uses Laravel Vite and expects a manifest at public/build/manifest.json.
# Build it automatically if it's missing so the app boots without a 500 error.
if [[ ! -f public/build/manifest.json ]]; then
  npm --workspace resources/assets/v2 run build
fi

# Generate a local APP_KEY if the placeholder is still present.
php artisan key:generate --force

echo "Dev container bootstrap complete. Next:" \
  && echo "- In the container terminal: php artisan firefly-iii:upgrade-database --force" \
  && echo "- Then: php artisan firefly-iii:laravel-passport-keys" \
  && echo "- (Assets are auto-built on first run if missing)" \
  && echo "- Run: php artisan serve --host=0.0.0.0 --port=8000 (visit http://127.0.0.1:8001)"
