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

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Ensure production mode defaults are declared globally
ENV APP_ENV=prod
ENV AUTO_DUMP_AUTOLOAD=1

# Copy composer structural definitions first to cache layer builds
COPY composer.json composer.lock* ./

# --- FIXED LINE: Added --no-scripts to prevent bin/console execution loops ---
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts

# Copy the rest of the application files over the dependency maps (This brings in bin/)
COPY . .

# Force dump an authoritative production classmap and execute post-build script definitions
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