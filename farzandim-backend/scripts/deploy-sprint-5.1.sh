#!/usr/bin/env bash
# Sprint 5.1 deploy — server tomonida bir martalik ishlatiladi.
# Mac'dan: ssh farzandim@95.182.118.39 'bash -s' < scripts/deploy-sprint-5.1.sh
# yoki SSH qilib qo'lda:
#   curl -sL https://raw.githubusercontent.com/polvonuzb/farzandim-backend/main/scripts/deploy-sprint-5.1.sh | bash
#
# Idempotent: qayta-qayta ishlatish xavfsiz. Mavjud sirlarga tegmaydi —
# faqat ADMIN_JWT_* yo'q bo'lsa qo'shadi.

set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-/home/farzandim/backend}"
SERVICE_NAME="${SERVICE_NAME:-farzandim-backend.service}"

cd "$BACKEND_DIR"

echo "==> 1/7  Permission tuzatish (kerak bo'lsa)"
sudo chown -R "$(whoami):$(whoami)" .git 2>/dev/null || true

echo "==> 2/7  Git pull origin main"
git pull origin main

echo "==> 3/7  ADMIN_JWT sirlarini tekshirish va kerak bo'lsa qo'shish"
add_secret() {
  local key="$1" value="$2"
  if ! grep -q "^${key}=" .env 2>/dev/null; then
    echo "${key}=${value}" | sudo tee -a .env >/dev/null
    echo "    + ${key} qo'shildi"
  else
    echo "    = ${key} allaqachon mavjud (saqlandi)"
  fi
}

add_secret "ADMIN_JWT_ACCESS_SECRET"  "$(openssl rand -hex 32)"
add_secret "ADMIN_JWT_REFRESH_SECRET" "$(openssl rand -hex 32)"
add_secret "ADMIN_JWT_ACCESS_EXPIRES" "15m"
add_secret "ADMIN_JWT_REFRESH_EXPIRES" "30d"

echo "==> 4/7  npm install (bcryptjs olinadi)"
npm install --silent

echo "==> 5/7  Prisma migrate deploy + generate"
npx prisma migrate deploy
npx prisma generate

echo "==> 6/7  TypeScript build"
npm run build

echo "==> 7/7  Service restart + health check"
sudo systemctl restart "$SERVICE_NAME"
sleep 2
sudo systemctl is-active "$SERVICE_NAME"
curl -sS http://127.0.0.1:3000/api/health | head -1
echo ""

echo "==> Deploy yakuni."
echo ""
echo "Keyingi: birinchi super_admin moderator yaratish:"
echo "    ADMIN_SEED_PASSWORD='kuchli-parol-bu-yerda' npx tsx prisma/seed-admin.ts"
echo ""
echo "Yoki API orqali smoke test:"
echo "    curl -i https://farzandimedu.uz/api/admin/auth/staff-me   # 401 expected"
