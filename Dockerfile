# Multi-stage build for optimized production image
FROM php:8.3-fpm AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    nginx \
    libpq-dev \
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install \
    pdo_mysql \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Force PHP-FPM's default pool to listen over standard 127.0.0.1:9000 instead of a Unix socket
RUN sed -i 's|listen = /var/run/php-fpm.sock|listen = 127.0.0.1:9000|g' /usr/local/etc/php-fpm.d/www.conf

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# === FIX 1: Allow Plugins to run as Root & Optimize Environment ===
ENV APP_ENV=prod
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV DATABASE_URL="sqlite:///:memory:"

# Copy composer structural definitions first to cache layer builds
COPY composer.json composer.lock* ./

# === FIX 2: Added --no-scripts to skip the broken symfony-cmd entirely ===
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts

# Copy the rest of the application files over the dependency maps (Brings in bin/ and src/)
COPY . .

# Clean dump an authoritative production classmap manually
RUN composer dump-autoload --no-dev --classmap-authoritative

# --- COPIED NGINX CONFIGURATIONS ---
COPY nginx-main.conf /etc/nginx/nginx.conf
RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-enabled /etc/nginx/sites-available
COPY nginx.conf /etc/nginx/conf.d/symfony.conf

# Copy and set up entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose HTTP port 80 for production web traffic
EXPOSE 80

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]