FROM mcr.microsoft.com/devcontainers/php:1-8.4-bookworm

# Install system deps, PHP extensions, Node.js
#
# The upstream devcontainers base image may ship a Yarn APT repository.
# If that repo's signing key isn't present, `apt-get update` fails.
# We don't need Yarn for this project (npm workspaces are used), so we remove it.
RUN rm -f /etc/apt/sources.list.d/yarn.list /etc/apt/trusted.gpg.d/yarn.gpg || true

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        libicu-dev \
        libzip-dev \
        zlib1g-dev \
        default-mysql-client \
    && docker-php-ext-install -j"$(nproc)" intl bcmath pdo_mysql zip \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
