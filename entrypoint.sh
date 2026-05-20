#!/bin/sh
set -e

echo "System Architecture Initializing..."

# Ensure absolute paths for runtime directories exist
mkdir -p /app/var/cache /app/var/log /app/var/tmp

# Explicitly export execution variables to subshells
export APP_ENV=prod

# Force recursive ownership of runtime directories to the web server user
chown -R www-data:www-data /app/var
chmod -R 775 /app/var

echo "Warmbooting Symfony Cache Context..."
su -s /bin/sh -c "php /app/bin/console cache:clear --env=prod --no-warmup" www-data
sleep 1

# Run database migrations automatically during deployment
echo "Running Production Database Migrations..."
php /app/bin/console doctrine:migrations:migrate --no-interaction --env=prod --allow-no-migration
sleep 1

# Start PHP-FPM in the foreground
echo "Starting PHP-FPM Service Engine..."
php-fpm -F &
PHP_PID=$!

# Start Nginx in the foreground
echo "Starting Nginx Reverse Proxy..."
nginx -g "daemon off;" &
NGINX_PID=$!

echo "Containers are active. Monitoring status tracks..."
while kill -0 "$PHP_PID" 2>/dev/null && kill -0 "$NGINX_PID" 2>/dev/null; do
    sleep 2
done

echo "Critical process failure detected. Container shutting down."
exit 1