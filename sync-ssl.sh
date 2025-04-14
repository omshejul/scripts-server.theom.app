#!/bin/bash

DOMAIN="rmp.theom.app"
LE_PATH="/etc/letsencrypt/live/$DOMAIN"
ISP_SSL_PATH="/var/www/clients/client0/web8/ssl"
APACHE_SERVICE="apache2"

echo "📦 Syncing Let's Encrypt cert for $DOMAIN..."

# Backup existing certs
cp "$ISP_SSL_PATH/$DOMAIN.crt" "$ISP_SSL_PATH/$DOMAIN.crt.bak"
cp "$ISP_SSL_PATH/$DOMAIN.key" "$ISP_SSL_PATH/$DOMAIN.key.bak"

# Copy new certs
cp "$LE_PATH/fullchain.pem" "$ISP_SSL_PATH/$DOMAIN.crt"
cp "$LE_PATH/privkey.pem" "$ISP_SSL_PATH/$DOMAIN.key"

# Permissions
chown root:root "$ISP_SSL_PATH/$DOMAIN.crt" "$ISP_SSL_PATH/$DOMAIN.key"
chmod 600 "$ISP_SSL_PATH/$DOMAIN.key"

# Restart Apache
systemctl restart $APACHE_SERVICE

echo "✅ Synced and restarted Apache for $DOMAIN"