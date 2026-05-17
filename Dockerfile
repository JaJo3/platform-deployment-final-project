# Multi-stage build for optimized production image
FROM php:8.3-fpm AS base

# Install system dependencies (ADDED nginx here)
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

# Copy composer files and application code
COPY composer.json composer.lock* ./
COPY . .

# Install dependencies (with an inline variable to prevent dotenv lookup crashes)
RUN APP_ENV=prod composer install --no-dev --optimize-autoloader --no-interaction
# --- COPIED NGINX CONFIGURATIONS (As per your project requirements) ---
COPY nginx-main.conf /etc/nginx/nginx.conf
RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-enabled /etc/nginx/sites-available
COPY nginx.conf /etc/nginx/conf.d/symfony.conf

# Copy and set up entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set proper permissions
RUN chown -R www-data:www-data /app && chmod -R 777 /app/var

# Create cache and logs directories
RUN mkdir -p var/cache var/log var/tmp && chown -R www-data:www-data var && chmod -R 777 var

# Expose HTTP port 80 for production web traffic instead of 9000
EXPOSE 80

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]