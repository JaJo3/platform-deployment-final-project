#!/bin/bash
set -e

# Ensure absolute paths for runtime directories exist
echo "Fixing directory permissions..."
mkdir -p /app/var/cache /app/var/log /app/var/tmp

# Force recursive ownership of the runtime tracks to www-data
chown -R www-data:www-data /app/var
chmod -R 775 /app/var

# Clear cache AS the www-data user so root doesn't hijack ownership
echo "Clearing cache..."
su -s /bin/bash -c "php bin/console cache:clear --env=prod --no-warmup" www-data
sleep 1

# Run database migrations automatically during deployment
echo "Running migrations..."
php bin/console doctrine:migrations:migrate --no-interaction --env=prod
sleep 1

# Start PHP-FPM in the foreground
echo "Starting PHP-FPM..."
php-fpm -F &
PHP_PID=$!

# Start Nginx in the foreground
echo "Starting Nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

# Wait for either process to exit
wait -n
exit $?