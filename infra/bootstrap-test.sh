#!/usr/bin/env bash
# =============================================================================
# Farzandim — YANGI platforma "bootstrap" (test.farzandimedu.uz)
# -----------------------------------------------------------------------------
# Bu skript yangi versiyani server "chetida" (alohida papka/port/DB/MinIO)
# ishlashga TAYYORLAYDI. ESKI platformaga (farzandim-backend :3000, eski nginx,
# eski DB, eski MinIO :9000) UMUMAN TEGMAYDI.
#
# Idempotent: bir necha marta ishlatса bo'ladi.
#
# Ishlatish (serverda):
#   SUDO_PW='<parol>' bash ~/new-platform/bootstrap-test.sh
#
# Nimalarni sozlaydi:
#   1. ~/new-platform/{backend,admin-web,flutter/{parent,child},minio-data}
#   2. Postgres: yangi DB `farzandim_v2` + rol (alohida parol)
#   3. Alohida MinIO instance :9100/:9101 (systemd) — eski :9000 ga tegmaydi
#   4. ~/new-platform/backend/.env  (yangi secretlar, openssl bilan generatsiya)
#   5. systemd: farzandim-v2-backend.service (:3100) — enable, lekin start qilmaydi
#   6. pm2 ecosystem (v2-admin :3101) + pm2 startup
#   7. sudoers NOPASSWD (faqat CI restart buyruqlari uchun)
#   8. nginx server-block test.farzandimedu.uz + certbot SSL
# =============================================================================
set -euo pipefail

: "${SUDO_PW:?SUDO_PW env kerak - sudo paroli}"

USER_NAME="$(id -un)"
HOME_DIR="$HOME"
BASE="$HOME_DIR/new-platform"
DOMAIN="test.farzandimedu.uz"
LE_EMAIL="bekmuhammad.devoloper@gmail.com"

DB_NAME="farzandim_v2"
DB_USER="farzandim_v2"
BACKEND_PORT="3100"
ADMIN_PORT="3101"
MINIO_API_PORT="9100"
MINIO_CON_PORT="9101"
MINIO_BIN="/usr/local/bin/minio"

# ---- sudo helper (askpass orqali parolsiz interaktiv emas) -------------------
PWFILE="$(mktemp)"; chmod 600 "$PWFILE"; printf '%s' "$SUDO_PW" > "$PWFILE"
ASKPASS="$(mktemp)"; chmod 700 "$ASKPASS"
printf '#!/bin/sh\ncat %s\n' "$PWFILE" > "$ASKPASS"; chmod +x "$ASKPASS"
export SUDO_ASKPASS="$ASKPASS"
trap 'rm -f "$PWFILE" "$ASKPASS"' EXIT
S() { command sudo -A "$@"; }

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# =============================================================================
log "1/8  Papkalar"
mkdir -p "$BASE/backend" "$BASE/admin-web" "$BASE/flutter/parent" \
         "$BASE/flutter/child" "$BASE/minio-data" "$BASE/secrets"
chmod 700 "$BASE/secrets"

# ---- secret generatsiya / saqlash (idempotent) ------------------------------
gen_secret() { # $1 = fayl nomi, $2 = uzunlik (hex)
  local f="$BASE/secrets/$1"
  if [ ! -s "$f" ]; then openssl rand -hex "${2:-32}" > "$f"; chmod 600 "$f"; fi
  cat "$f"
}
DB_PASS="$(gen_secret db_pass 24)"
JWT_ACCESS="$(gen_secret jwt_access 32)"
JWT_REFRESH="$(gen_secret jwt_refresh 32)"
ADMIN_JWT_ACCESS="$(gen_secret admin_jwt_access 32)"
ADMIN_JWT_REFRESH="$(gen_secret admin_jwt_refresh 32)"
MINIO_ROOT_USER="farzandimv2"
MINIO_ROOT_PASS="$(gen_secret minio_root 24)"

# =============================================================================
log "2/8  Postgres: $DB_NAME bazasi + $DB_USER roli"
S -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$do\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='$DB_USER') THEN
    CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASS';
  ELSE
    ALTER ROLE $DB_USER LOGIN PASSWORD '$DB_PASS';
  END IF;
END \$do\$;
SQL
if ! S -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  S -u postgres createdb -O "$DB_USER" "$DB_NAME"
  echo "   yangi baza yaratildi: $DB_NAME"
else
  echo "   baza allaqachon mavjud: $DB_NAME"
fi
S -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" <<SQL
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER SCHEMA public OWNER TO $DB_USER;
SQL

# =============================================================================
log "3/8  Alohida MinIO instance (:$MINIO_API_PORT) — eski :9000 ga tegmaydi"
S tee /etc/systemd/system/farzandim-v2-minio.service >/dev/null <<UNIT
[Unit]
Description=Farzandim v2 MinIO (test)
After=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
Environment="MINIO_ROOT_USER=$MINIO_ROOT_USER"
Environment="MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASS"
ExecStart=$MINIO_BIN server $BASE/minio-data --address 127.0.0.1:$MINIO_API_PORT --console-address 127.0.0.1:$MINIO_CON_PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
S systemctl daemon-reload
S systemctl enable --now farzandim-v2-minio.service
sleep 2
systemctl is-active farzandim-v2-minio.service && echo "   v2-minio ishlayapti"

# =============================================================================
log "4/8  backend/.env (yangi secretlar bilan)"
ENVF="$BASE/backend/.env"
if [ -f "$ENVF" ]; then cp "$ENVF" "$ENVF.bak.$(date +%s)"; fi
cat > "$ENVF" <<ENV
NODE_ENV=production
PORT=$BACKEND_PORT
HOST=127.0.0.1
LOG_LEVEL=info

CORS_ORIGINS=https://$DOMAIN

DATABASE_URL="postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME?schema=public"

# ⚠️ TEST placeholder — haqiqiy Telegram bot tokenini keyin qo'ying (>=40 belgi)
TELEGRAM_BOT_TOKEN=0000000000:TEST_PLACEHOLDER_TOKEN_REPLACE_ME_0123456789
TELEGRAM_BOT_USERNAME=farzandim_test_bot

JWT_ACCESS_SECRET=$JWT_ACCESS
JWT_REFRESH_SECRET=$JWT_REFRESH
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=30d

ADMIN_JWT_ACCESS_SECRET=$ADMIN_JWT_ACCESS
ADMIN_JWT_REFRESH_SECRET=$ADMIN_JWT_REFRESH
ADMIN_JWT_ACCESS_EXPIRES=15m
ADMIN_JWT_REFRESH_EXPIRES=30d

MINIO_ENDPOINT=http://127.0.0.1:$MINIO_API_PORT
MINIO_ACCESS_KEY=$MINIO_ROOT_USER
MINIO_SECRET_KEY=$MINIO_ROOT_PASS
MINIO_PUBLIC_URL=https://$DOMAIN/storage

PUBLIC_BASE_URL=https://$DOMAIN

PAYME_MERCHANT_ID=
PAYME_MERCHANT_KEY=
CLICK_SERVICE_ID=
CLICK_MERCHANT_ID=
CLICK_SECRET_KEY=
UZUM_MERCHANT_SERVICE_ID=
UZUM_SECRET_KEY=
PAYMENT_WEBHOOK_IPS=
ESKIZ_EMAIL=
ESKIZ_PASSWORD=
ESKIZ_FROM=4546
ENV
chmod 600 "$ENVF"
echo "   yozildi: $ENVF"

# =============================================================================
log "5/8  systemd: farzandim-v2-backend.service (:$BACKEND_PORT)"
S tee /etc/systemd/system/farzandim-v2-backend.service >/dev/null <<UNIT
[Unit]
Description=Farzandim v2 Backend (NestJS, test)
After=network.target postgresql.service farzandim-v2-minio.service

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$BASE/backend
ExecStart=/usr/bin/node $BASE/backend/dist/main.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=$BASE/backend/.env

[Install]
WantedBy=multi-user.target
UNIT
S systemctl daemon-reload
S systemctl enable farzandim-v2-backend.service
echo "   enable qilindi (kod kelgach deploy ishga tushiradi)"

# =============================================================================
log "6/8  pm2 ecosystem (v2-admin :$ADMIN_PORT) + startup"
cat > "$BASE/ecosystem.config.js" <<ECO
module.exports = {
  apps: [
    {
      name: 'v2-admin',
      cwd: '$BASE/admin-web',
      script: 'npm',
      args: 'run start',
      env: { NODE_ENV: 'production', PORT: '$ADMIN_PORT' },
      max_restarts: 10,
      autorestart: true,
    },
  ],
};
ECO
# pm2'ni boot'da ishga tushirish (systemd integration)
S env PATH="$PATH" /usr/bin/pm2 startup systemd -u "$USER_NAME" --hp "$HOME_DIR" >/dev/null 2>&1 || true
pm2 save >/dev/null 2>&1 || true
echo "   ecosystem yozildi: $BASE/ecosystem.config.js"

# =============================================================================
log "7/8  sudoers NOPASSWD (faqat CI restart buyruqlari)"
S tee /etc/sudoers.d/farzandim-v2 >/dev/null <<SUDOERS
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/systemctl restart farzandim-v2-backend.service, /usr/bin/systemctl restart farzandim-v2-minio.service, /usr/bin/systemctl reload nginx, /usr/bin/systemctl restart nginx
SUDOERS
S chmod 440 /etc/sudoers.d/farzandim-v2
S visudo -cf /etc/sudoers.d/farzandim-v2 && echo "   sudoers OK"

# =============================================================================
log "8/8  nginx + SSL ($DOMAIN)"
S tee /etc/nginx/sites-available/$DOMAIN >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    client_max_body_size 100M;

    # Backend API (NestJS, global prefix /api)
    location /api/ {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Realtime (socket.io)
    location /socket.io/ {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # MinIO (yangi instance) public obyektlar
    location /storage/ {
        proxy_pass http://127.0.0.1:$MINIO_API_PORT/;
        proxy_set_header Host \$host;
    }

    # Flutter parent (statik)
    location /app/ {
        alias $BASE/flutter/parent/;
        try_files \$uri \$uri/ /app/index.html;
    }

    # Flutter child (statik)
    location /child/ {
        alias $BASE/flutter/child/;
        try_files \$uri \$uri/ /child/index.html;
    }

    # Admin panel (Next.js) — root
    location / {
        proxy_pass http://127.0.0.1:$ADMIN_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX
S ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
S nginx -t
S systemctl reload nginx
echo "   nginx HTTP config faol"

# SSL — DNS allaqachon serverga ishora qiladi
if S certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$LE_EMAIL" --redirect; then
  echo "   ✅ SSL o'rnatildi: https://$DOMAIN"
else
  echo "   ⚠️ certbot bajarilmadi — keyin qo'lda: sudo certbot --nginx -d $DOMAIN"
fi

# =============================================================================
log "BOOTSTRAP TUGADI ✅"
cat <<SUMMARY

  Backend  :  systemd farzandim-v2-backend  (port $BACKEND_PORT)  [kod kutmoqda]
  Admin    :  pm2 v2-admin                   (port $ADMIN_PORT)   [kod kutmoqda]
  MinIO v2 :  systemd farzandim-v2-minio     (port $MINIO_API_PORT)  ✅ ishlayapti
  Database :  $DB_NAME (rol: $DB_USER)        ✅ tayyor (bo'sh)
  Domain   :  https://$DOMAIN

  Secretlar: $BASE/secrets/  (600)
  Keyingi qadam: CI/CD yoki to'g'ridan deploy → kod keladi → servislar ishga tushadi.
SUMMARY
