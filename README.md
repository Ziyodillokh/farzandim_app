# Farzandim — Oilaviy aloqa va ta'lim platformasi

> O'zbekiston ota-onalari va 6–18 yoshli bolalar uchun yagona raqamli ekotizim. Ota-onaga xavfsiz nazorat, bolaga rivojlanish platformasi.

## Loyiha strukturasi (Monorepo)

```
farzandim/
├── backend/              # NestJS backend (production) — REST API + WebSocket
├── farzandim-backend/    # Eski Fastify backend (reference / rollback)
├── Farzandim/            # Flutter Parent App (mobil)
├── farzandim_child/      # Flutter Child App (mobil)
├── frontend-web/         # Next.js 15 web (Parent Dashboard + Admin Panel)
└── tz/                   # Mahsulot konsept hujjati
```

## Texnik stek

| Komponent | Texnologiya |
|-----------|-------------|
| Backend | NestJS 11 + Fastify adapter + Prisma + PostgreSQL |
| Realtime | Socket.io |
| Storage | MinIO (S3-compatible) |
| Push notifications | Firebase Cloud Messaging |
| SMS | Eskiz.uz |
| Payments | Payme + Click + Uzum Bank |
| Mobile apps | Flutter 3.x + Riverpod + go_router |
| Web | Next.js 15 + TypeScript + TailwindCSS + shadcn/ui |
| Database | PostgreSQL 17 + 22 migrations |

## Asosiy funksiyalar

### Parent App
- Real-time geolokatsiya + harakatlanish tarixi
- Geo-zonalar (uy, maktab) — kirish/chiqish bildirishnoma
- Ekran vaqti + ilova cheklovlari
- SOS qabul qilish (push, lokatsiya)
- Voice/Video xabar
- Bolaning XP, daraja, yutuqlar paneli
- Foto so'rov

### Child App
- Olimpiadalar va konkurslar
- Audiokitoblar, kitoblar, videolar
- FARO chatbot
- Xavfsiz messenger
- Gamifikatsiya (XP, daraja, streak)
- SOS tugmasi

### Admin Panel
- Moderator boshqaruvi + 2FA (TOTP + backup codes)
- Kontent moderatsiyasi (videos, audiobooks, books)
- Foydalanuvchi boshqaruvi
- Olimpiada CRUD
- Monetizatsiya (tariflar, promokodlar)
- Broadcast bildirishnomalar
- Tahlil paneli (user growth, engagement, revenue)
- Audit log

### Backend xususiyatlari
- 156 REST endpoint, to'liq Swagger hujjat
- JWT auth (consumer + admin alohida audience)
- RBAC (super_admin, finance, content_maker, support, custom)
- Audit log har bir CUD operatsiyasi
- 22 Prisma migration
- 41 ma'lumotlar modeli
- Payme JSON-RPC, Click MD5, Uzum SHA256 webhook'lar

## Mahalliy ishga tushirish

### Backend (NestJS)
```bash
cd backend
cp .env.example .env  # to'ldiring
npm install
npx prisma generate
npx prisma migrate deploy
npm run start:dev      # port 3000
```

### Flutter Parent App
```bash
cd Farzandim
flutter pub get
flutter run --dart-define-from-file=env.json
```

### Flutter Child App
```bash
cd farzandim_child
flutter pub get
flutter run --dart-define-from-file=env.json
```

### Web (Next.js)
```bash
cd frontend-web
npm install
npm run dev            # port 5173
```

## Litsenziya

Tijorat loyihasi. Barcha huquqlar himoyalangan © 2026 Farzandim.
