#!/bin/bash

# Usage: ./setup-ssl.sh --domain example.com --docroot /path/to/site
# Example sudo bash /root/server/scripts/setup-ssl.sh \
#  --domain api.theom.app \
#  --docroot /var/www/clients/client0/web9

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --docroot) DOCROOT="$2"; shift ;;
    *) echo "Unknown param: $1"; exit 1 ;;
  esac
  shift
done


# Load .env if it exists
ENV_PATH="$(dirname "$0")/.env"
if [ -f "$ENV_PATH" ]; then
  set -a
  source "$ENV_PATH"
  set +a
fi

# Abort if LE_EMAIL is not set
if [ -z "$LE_EMAIL" ]; then
  echo "❌ ERROR: LE_EMAIL is not set. Please create a .env file with:"
  echo "LE_EMAIL=your@email.com"
  exit 1
fi

EMAIL="$LE_EMAIL"

SSL_PATH="$DOCROOT/ssl"
LE_PATH="/etc/letsencrypt/live/$DOMAIN"
SYNC_SCRIPT="/root/server/scripts/sync-ssl-${DOMAIN}.sh"
HOOK_SCRIPT="/etc/letsencrypt/renewal-hooks/post/99-sync-${DOMAIN}.sh"

# 1. Generate Cert
echo "🔐 Generating cert for $DOMAIN..."
certbot --apache -d "$DOMAIN" -m "$EMAIL" --agree-tos --no-eff-email

# 2. Create Sync Script
echo "📄 Creating sync script: $SYNC_SCRIPT"
cat <<EOF > "$SYNC_SCRIPT"
#!/bin/bash

# Auto-sync certs for $DOMAIN
cp "$SSL_PATH/$DOMAIN.crt" "$SSL_PATH/$DOMAIN.crt.bak"
cp "$SSL_PATH/$DOMAIN.key" "$SSL_PATH/$DOMAIN.key.bak"

cp "$LE_PATH/fullchain.pem" "$SSL_PATH/$DOMAIN.crt"
cp "$LE_PATH/privkey.pem" "$SSL_PATH/$DOMAIN.key"

chown root:root "$SSL_PATH/$DOMAIN.crt" "$SSL_PATH/$DOMAIN.key"
chmod 600 "$SSL_PATH/$DOMAIN.key"

systemctl restart apache2
echo "✅ SSL synced and Apache restarted for $DOMAIN"
EOF

chmod +x "$SYNC_SCRIPT"

# 3. Create Renewal Hook
echo "🔁 Setting up renewal hook: $HOOK_SCRIPT"
cat <<EOF > "$HOOK_SCRIPT"
#!/bin/bash

LOG="/tmp/ssl-sync-${DOMAIN}-\$(date +%F-%T).log"
bash "$SYNC_SCRIPT" > "\$LOG" 2>&1
mail -s "[$DOMAIN] SSL Renewed" "$EMAIL" < "\$LOG"
rm "\$LOG"
EOF

chmod +x "$HOOK_SCRIPT"

echo "🎉 Done! SSL is live and auto-renew + sync is set up for $DOMAIN"