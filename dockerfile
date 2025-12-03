FROM php:8.2-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl zip unzip libzip-dev nginx supervisor \
    && docker-php-ext-install zip pdo_mysql mysqli \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create nginx.conf inline
RUN echo 'server { \
    listen 80; \
    root /var/www/html; \
    index index.php index.html index.htm; \
    \
    location / { \
        try_files \$uri \$uri/ /index.php?\$query_string; \
    } \
    \
    location ~ \.php\$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_index index.php; \
        include fastcgi_params; \
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; \
    } \
    \
    location ~ /\.ht { \
        deny all; \
    } \
    \
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/sites-available/default \
&& ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/ \
&& rm /etc/nginx/sites-enabled/default

# Create supervisord.conf inline
RUN echo '[supervisord] \
nodaemon=true \
user=root \
\
[program:php-fpm] \
command=php-fpm8.2 -F \
directory=/var/www/html \
autostart=true \
autorestart=true \
\
[program:nginx] \
command=nginx -g "daemon off;" \
autostart=true \
autorestart=true' > /etc/supervisor/conf.d/supervisord.conf

# Copy installer and download/extract X3
COPY x3_installer.php /var/www/html/
RUN curl -L https://www.photo.gallery/download/x3.latest.flat.zip -o /tmp/x3.zip \
    && mkdir -p /var/www/html/x3 \
    && cd /var/www/html/x3 \
    && unzip /tmp/x3.zip \
    && rm /tmp/x3.zip \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Create directories X3 installer expects
RUN mkdir -p /var/www/html/x3/_cache/pages /var/www/html/x3/render \
    && chown -R www-data:www-data /var/www/html/x3/_cache /var/www/html/x3/render

EXPOSE 80
WORKDIR /var/www/html
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
