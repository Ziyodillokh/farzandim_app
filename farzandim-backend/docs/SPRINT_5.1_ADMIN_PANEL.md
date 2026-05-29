# Sprint 5.1 — Admin Panel Backend Modullari

> **Maqsad:** Flutter Web admin paneli (`/Users/raxmonjon/Projects/admin_panel/admin_panel`) uchun real production endpoint'larini ochish. Mavjud Telegram auth, consumer endpoint'lar va Prisma modellariga **tegmagan**.

---

## ✏️ Nima qo'shildi

### Prisma
- Yangi model: `Moderator` (`prisma/schema.prisma`)
- Yangi migration: `prisma/migrations/20260518000000_add_moderator/migration.sql`

### Source
```
src/
├── config/env.ts                          # +4 ADMIN_JWT_* env vars
├── middleware/staff-auth.ts               # YANGI
├── lib/admin-permissions.ts               # YANGI (23 perm key + role presets)
├── modules/
│   ├── admin-auth/                        # YANGI
│   │   ├── password.ts
│   │   ├── jwt.ts
│   │   └── routes.ts                      # login, 2fa-stub, refresh, staff-me, change-password
│   ├── admin-moderators/routes.ts         # YANGI: list, get, create, update, block, unblock, delete
│   ├── admin-users/routes.ts              # YANGI: parents+children unified projection
│   └── admin-dashboard/routes.ts          # YANGI: real DB KPI aggregations
└── server.ts                              # +4 register satrlari
```

### Bog'liqliklar
- `package.json`: `+bcryptjs`, `+@types/bcryptjs`

### Misol .env qo'shimchasi
- `.env.example`: `+ADMIN_JWT_ACCESS_SECRET`, `+ADMIN_JWT_REFRESH_SECRET`, `+ADMIN_JWT_ACCESS_EXPIRES`, `+ADMIN_JWT_REFRESH_EXPIRES`

### Seed
- `prisma/seed-admin.ts` — 4 demo moderator (PDF dizaynidagi rollar)

---

## 🔌 Yangi endpoint'lar (production: https://farzandimedu.uz)

| Method | Path | Auth | Maqsad |
|---|---|---|---|
| POST | `/api/admin/auth/login` | – | email+password → access/refresh JWT (audience='admin-panel') |
| POST | `/api/admin/auth/2fa/verify` | – | stub (501) |
| POST | `/api/admin/auth/refresh` | – | refresh JWT |
| GET  | `/api/admin/auth/staff-me` | Bearer | joriy staff profili |
| POST | `/api/admin/auth/change-password` | Bearer | parol almashtirish |
| GET  | `/api/admin/moderators` | Bearer | list (q, role, status, page, limit) |
| GET  | `/api/admin/moderators/:id` | Bearer | bitta moderator |
| POST | `/api/admin/moderators` | Bearer | yaratish |
| PATCH | `/api/admin/moderators/:id` | Bearer | tahrirlash |
| POST | `/api/admin/moderators/:id/block` | Bearer | bloklash |
| POST | `/api/admin/moderators/:id/unblock` | Bearer | tiklash |
| DELETE | `/api/admin/moderators/:id` | Bearer | o'chirish |
| GET  | `/api/admin/users` | Bearer | ota-onalar + bolalar yagona ro'yxati (real DB) |
| GET  | `/api/admin/users/:id` | Bearer | ota-ona tafsiloti + bolalar ro'yxati |
| GET  | `/api/admin/users/child-profiles/:id` | Bearer | bola + ChildProfile + 10 oxirgi XpEvent |
| GET  | `/api/admin/dashboard?from=&to=` | Bearer | KPI + chart (real DB) |

---

## 🚀 Deploy qadamlari

### 1. Mac'dan kod tekshirish va git commit

```bash
cd /Users/raxmonjon/Projects/farzandim-backend

# Tekshirish — type-check toza bo'lishi shart
npm install          # bcryptjs + @types/bcryptjs olinadi
npx prisma generate
npx tsc --noEmit     # 0 xato

git status           # 12+ yangi/o'zgartirilgan fayl
git add -A
git commit -m "feat(admin): Sprint 5.1 admin panel backend modullari

- Yangi Moderator Prisma model + migration
- Alohida admin JWT flow (audience='admin-panel')
- 4 ta yangi modul: admin-auth, admin-moderators, admin-users, admin-dashboard
- Mavjud Telegram auth, consumer endpoints va modellarga tegmagan

🤖 Generated with Claude Code"
git push origin main
```

### 2. Server'da yangi sirlar va deploy

```bash
ssh farzandim@95.182.118.39
cd /home/farzandim/backend

# Yangi admin sirlarini .env ga qo'shish
NEW_ADMIN_ACCESS=$(openssl rand -hex 32)
NEW_ADMIN_REFRESH=$(openssl rand -hex 32)
echo "ADMIN_JWT_ACCESS_SECRET=$NEW_ADMIN_ACCESS" | sudo tee -a .env
echo "ADMIN_JWT_REFRESH_SECRET=$NEW_ADMIN_REFRESH" | sudo tee -a .env
echo "ADMIN_JWT_ACCESS_EXPIRES=15m" | sudo tee -a .env
echo "ADMIN_JWT_REFRESH_EXPIRES=30d" | sudo tee -a .env

# Permission issue bo'lsa
sudo chown -R farzandim:farzandim .git

# Pull, install, migrate, generate, build, restart
git pull origin main
npm install
npx prisma migrate deploy   # add_moderator migration tushadi
npx prisma generate
npm run build
sudo systemctl restart farzandim-backend.service

# Health check
curl https://farzandimedu.uz/api/health
curl https://farzandimedu.uz/api/admin/auth/staff-me -i  # 401 expected (no token)
```

### 3. Birinchi super_admin moderator seed

```bash
# Server'da (1Password yoki kuchli parol ishlatishni unutmang!):
ADMIN_SEED_PASSWORD="kuchli-parol-bu-yerda" npx tsx prisma/seed-admin.ts
```

Bu 4 ta moderatorni yaratadi:
- `admin@farzandim.uz` — super_admin
- `finance@farzandim.uz` — finance (blocked)
- `content@farzandim.uz` — content_maker
- `support@farzandim.uz` — support

Hamma uchun bir xil parol o'rnatiladi. Birinchi login qilgandan keyin har biri parolini o'zgartirsin (`/api/admin/auth/change-password` endpoint).

### 4. Smoke test (production'da)

```bash
TOKEN=$(curl -sS -X POST https://farzandimedu.uz/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@farzandim.uz\",\"password\":\"$ADMIN_SEED_PASSWORD\"}" | jq -r .access_token)

curl -sS -H "Authorization: Bearer $TOKEN" https://farzandimedu.uz/api/admin/auth/staff-me | jq .
curl -sS -H "Authorization: Bearer $TOKEN" "https://farzandimedu.uz/api/admin/users?limit=5" | jq .
curl -sS -H "Authorization: Bearer $TOKEN" "https://farzandimedu.uz/api/admin/dashboard" | jq .
```

### 5. Flutter Web admin panel'ni ulash

Lokal Flutter dev (testing):
```bash
cd /Users/raxmonjon/Projects/admin_panel/admin_panel
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1 \
  --dart-define=API_BASE_URL=https://farzandimedu.uz/api \
  --dart-define=FLAVOR=prod
```

Production build (Nginx orqali admin.farzandimedu.uz subdomain'da xizmat qilish uchun):
```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://farzandimedu.uz/api \
  --dart-define=FLAVOR=prod
# build/web/ → server: /home/farzandim/admin-panel-web/ ga ko'chirish
```

---

## 🔒 Xavfsizlik qaydlari

1. **JWT izolyatsiyasi** — admin token mavjud `/api/users/me` ga ishlatib bo'lmaydi (audience='admin-panel' bilan ajratilgan). Consumer token ham admin route'ga ishlamaydi.
2. **2FA** — hozircha o'chirilgan. Production'ga chiqarishdan oldin TOTP yoki SMS 2FA qo'shish tavsiya etiladi.
3. **CORS** — backend hozir `origin: true` (har qanday) bilan ochiq. Production'da admin paneli `admin.farzandimedu.uz` subdomain'ga deploy bo'lganda CORS oq ro'yxatga olish kerak.
4. **Rate limit** — login endpoint'ida brute-force himoyasi yo'q. `@fastify/rate-limit` qo'shish tavsiya.
5. **Audit log** — admin harakatlari (create, block, delete) `AuditLog` jadvaliga yozilmaydi. Sprint 5.x'da qo'shamiz.

---

## ⏭ Keyingi qadamlar (Sprint 5.2+)

| Modul | Real DB | Status |
|---|---|---|
| Admin: Videolar (content moderation) | Video/Audiobook modellari **yo'q hali** | Modellarni qo'shish kerak |
| Admin: Audiokitoblar | Audiobook modeli yo'q | Modelni qo'shish kerak |
| Admin: O'yinlar | Game modeli yo'q | Modelni qo'shish kerak |
| Admin: Konkurslar | Contest modeli yo'q | Modelni qo'shish kerak |
| Admin: Monetizatsiya (Tariflar, Promokod, To'lov) | Subscription, Plan, Payment yo'q | Modellarni qo'shish kerak |
| Admin: Bildirishnoma (bulk push) | mavjud Notification model'ni qayta ishlatamiz | Tayyor |
| Admin: Analytics (revenue, content stats) | Modellar tugagandan keyin | Bog'langan |
| 2FA (TOTP) | Yangi `Staff2faSecret` modeli | TBD |
| Audit log (admin actions) | mavjud `AuditLog` model'dan foydalanamiz | Tayyor |
| Rate limit + brute-force | `@fastify/rate-limit` | TBD |

---

## 📞 Lokal dev test (deploysiz)

Lokal Postgres bilan ishlash uchun:
```bash
cd /Users/raxmonjon/Projects/farzandim-backend

# Lokal Postgres'da DB yaratish
createdb farzandim
echo 'DATABASE_URL="postgresql://localhost:5432/farzandim?schema=public"' > .env
echo 'ADMIN_JWT_ACCESS_SECRET="$(openssl rand -hex 32)"' >> .env
echo 'ADMIN_JWT_REFRESH_SECRET="$(openssl rand -hex 32)"' >> .env
# + boshqa env'lar (JWT_*, TELEGRAM_*, MINIO_*) misol fayldan

npx prisma migrate dev
ADMIN_SEED_PASSWORD="admin123" npx tsx prisma/seed-admin.ts
npm run dev
```

---

*Yaratildi: 2026-05-18 · Claude Code · Sprint 5.1*
