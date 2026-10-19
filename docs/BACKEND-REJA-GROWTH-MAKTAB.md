# Backend rejasi: Parvoz Growth (Daily Learning) va Parvoz School

Holat: 2026-10-19. Branch: `feat/learning-school-backend` (worktree
`farzandim_app-backend`). `main`ga push = production deploy (backend +
`prisma migrate deploy`) — har bosqich oxirida faqat ruxsat bilan.

## 0. Hozirgi holat (tahlil xulosasi)

- **Backend:** NestJS 11 (Fastify) + Prisma 6.19 + PostgreSQL. Global prefix
  `/api`. Modullar `src/modules/*` (iste'molchi) va `src/admin/*` (moderator).
- **Auth:** `User` (PARENT | CHILD) + consumer JWT; adminlar — alohida
  `Moderator`, 2FA (speakeasy), `PermissionsGuard`. Maktab / tenant tushunchasi
  YO'Q.
- **DON:** `GamificationService.awardXp` — idempotentlik `findFirst` bilan
  (unique indeks yo'q) va jami qiymatlar o'qib-yozish orqali → parallel
  chaqiruvlarda ikki marta berish / yo'qotish xavfi. Streak server vaqtida
  (Toshkent emas).
- **Testlar:** 8 ta unit spec (Prisma mock), e2e yo'q; deploy workflow test
  ishlatmaydi. Global filter Prisma P2002 ni 500 qaytaradi.
- **Bola ilovasi (Growth):** frontend tayyor, `LearningRepository` interfeysi
  orqali lokal ishlaydi (`feat/growth-redesign`).
- **Maktab paneli:** Next.js 15 statik eksport, butunlay brauzerda (mock
  `api.*`, localStorage, 35 jadval, 35 ruxsat, 6 rol). Yagona almashtirish
  nuqtasi — `school-panel/src/data/api.ts`.

## 1. Tamoyillar

1. **Faqat qo'shimcha migratsiyalar.** Yangi jadval / yangi nullable ustun /
   yangi enum qiymati. Mavjud jadvallarni buzmaymiz (prod ma'lumot bor).
2. **Server haqiqat manbai.** Ball, DON, ruxsatlar va maxfiylik (K=5) —
   faqat serverda hisoblanadi; klient ko'rsatadi.
3. **Toshkent kuni.** Kunlik mantiq (`day = YYYY-MM-DD`, Asia/Tashkent) bitta
   yordamchidan; cronlar `timeZone: 'Asia/Tashkent'`.
4. **Idempotentlik.** Javob (attemptId+questionId unique), yakunlash, DON
   (attempt'dagi `donAwardedAt` shartli yangilash bitta tranzaksiyada).
5. **Tenant izolyatsiyasi.** Har maktab so'rovi JWT'dagi `schoolId` bilan
   filtrlanadi; rol doirasi (SCHOOL / OWN_CLASS) servis qatlamida.
6. **Testlar:** sof funksiyalar — unit; har endpoint — haqiqiy Postgres'da
   e2e (docker). CI deploydan oldin testlarni ishlatadi.

## 2. Bosqichlar

### B0 — Poydevor (backend)
- E2E test infratuzilmasi: docker Postgres 16 (`docker-compose.test.yml`),
  `test/setup` (migrate deploy, jadvallarni tozalash), Fastify `inject`,
  FCM/SMS/Storage mock'lari, fabrikalar (parent, child, token).
- `GlobalExceptionFilter`: P2002 → 409, P2003 → 400 (mavjud javob formati
  saqlanadi).
- `common/time/tashkent.ts`: `tashkentDay()`, `tashkentDayRange()`,
  `addDays()`; streak hisobini Toshkent kuniga o'tkazish.
- `awardXp`: `increment` bilan atomik yangilash + tranzaksiya ichida ishlatish
  uchun `awardInTx(tx, …)`.
- CI: `deploy-test.yml`ga backend `test` job (Postgres service container,
  unit + e2e) — deploy unga bog'lanadi.

### G1 — Growth: Daily Learning backend
**Modellar (yangi):** `LearningProfile` (childId 1:1, grade, subjects[]),
`LearningQuestion` (externalId unique, subject, difficulty 1–3, min/maxGrade,
topic/prompt/options/explanation — `{uz,ru,en}` JSON, answerIndex, status),
`LearningAttempt` (childId, subject, day, isDaily, status, questionIds[],
correct/total, startedAt/completedAt, donEarned, donAwardedAt),
`LearningAnswer` (unique attemptId+questionId), `LearningReportDispatch`
(haftalik hisobot takrorlanmasin). Enum `XpEventType += DAILY_LEARNING`.
**Savollar banki:** 174 ta savol (10 fan, uz/ru/en, izohlar) — SQL data
migratsiya (`ON CONFLICT (externalId) DO NOTHING`).

**Bola (CHILD) API — `/api/learning`:**
| Metod | Yo'l | Vazifa |
|---|---|---|
| GET | `/profile` | sinf + fanlar (yo'q → `null`) |
| PUT | `/profile` | sinf + fanlar (validatsiya: sinfda o'qitiladi, 1–5 fan) |
| GET | `/today` | bugungi reja: fanlar, har biri bo'yicha urinish holati |
| POST | `/attempts` `{subject}` | boshlash yoki davom ettirish (javobsiz savollar + oldingi javoblar) |
| POST | `/attempts/:id/answers` | javob → `{isCorrect, correctIndex, explanation}` (idempotent) |
| POST | `/attempts/:id/complete` | yakun → natija + DON (kunlik birinchi urinish uchun) |
| GET | `/results` | natijalar tarixi (kursor) |
| GET | `/attempts/:id/review` | yakunlangan urinish tahlili |

- Adaptiv tanlov (Dart'dagi `pickQuestions` bilan bir xil): so'nggi 5 natija
  foizi → maqsadli qiyinlik, sinfga mos, yaqinda (3 kun) ko'rilganlar keyin.
- DON: `2 × to'g'ri + 10 (hammasi to'g'ri)`; faqat fan bo'yicha kunlik
  birinchi urinish; amaliyot urinishlari — 0.
- **Ota-ona (PARENT) API:** `GET /api/children/:childId/learning/summary`
  (7/30 kun: testlar, to'g'ri javoblar, o'rtacha, o'sish, fanlar, kuchli /
  e'tibor fan, faol kunlar, streak), `GET …/learning/results`,
  `PUT …/learning/profile`.
- **Haftalik hisobot:** yakshanba 19:00 (Toshkent) — ota-onaga push +
  `Notification` (uz/ru/en), takrorlanmaydi.
- **Admin API — `/api/admin/learning`** (`manage_learning` ruxsati): savollar
  CRUD, JSON import (validatsiya hisoboti bilan), statistika (savol
  aniqligi — juda oson / qiyin savollarni topish).

### G2 — Bola ilovasini backend'ga ulash (`feat/growth-redesign`)
- `LearningRepository` interfeysi server oqimiga: `startAttempt`,
  `submitAnswer`, `completeAttempt`, `loadReview` (+ profil, natijalar).
- `ApiLearningRepository` (Dio), lokal amalga oshirish testlar uchun qoladi.
- Test sessiyasi: tekshirish asinxron (server javobi), yarim qolgan test
  keyin davom ettiriladi, tarmoq xatolarida "Qayta urinish".
- `kLearningPreviewData = false`; APK.

### S1 — Maktab poydevori
- **Modellar:** `School`, `SchoolShift` + `SchoolBellPeriod`, `SchoolHoliday`,
  `SchoolClass`, `SchoolStaff` (+ sinf biriktirishlari), `SchoolAuditLog`,
  `SchoolStaffSession`.
- **Auth:** `/api/school/auth/login` (maktab kodi + login + parol, bcrypt,
  bloklash + rate limit), ixtiyoriy TOTP 2FA (direktor/admin), qisqa access
  JWT (audience `school-panel`) + rotatsiyalanadigan refresh (httpOnly
  cookie), logout, parol almashtirish.
- **Ruxsatlar:** panel `permissions.ts` (35 ruxsat, 6 rol, SCHOOL/OWN_CLASS)
  backend'ga ko'chiriladi; `SchoolAuthGuard` + `@SchoolPermission()` +
  `SchoolContext` (staff, schoolId, scope, classIds); har yozuvda audit.
- **API:** maktab profili, smenalar va qo'ng'iroqlar, bayramlar, sinflar,
  xodimlar CRUD.
- **Panel:** `src/data/http/*` adapter, `NEXT_PUBLIC_DATA_SOURCE=mock|http`;
  mock (demo) rejim saqlanadi — hozirgi demo sayt o'zgarmaydi.
- `scripts/create-school.ts` — maktab + direktor hisobini yaratish.

### S2 — O'quvchilar, ota-onalar va bog'lanish
- `SchoolStudent`, `SchoolGuardian`, o'quvchi↔vasiy, `SchoolStudentNote`,
  CSV import (oldindan ko'rish + xatolar hisoboti), arxiv, tarix.
- Taklif kodi (6 belgi, 7 kun) → ota-ona ilovasida kiritadi
  (`POST /api/school-links/redeem`) → vasiy `User`ga, o'quvchi bolaning
  `Child` yozuviga bog'lanadi (ota-ona tanlaydi).

### S3 — Davomat
- Belgilash, sinf kuni, tuzatishlar (sabab + audit), erta ketish so'rovlari,
  oylik hisobot va trend.
- Kiosk: server HMAC bilan imzolangan, 30 soniyada almashadigan QR;
  bola ilovasi skaner qiladi (`POST /api/school/check-in`), kioskda qidiruv.
- Kech qolish chegarasidan keyin "kelmadi" (cron) va ota-onaga push
  (keldi / ketdi / kelmadi / erta ketdi).

### S4 — Xabarlar
- E'lonlar (maktab / sinf darajasi / sinf / shaxs), ota-onalarga push,
  yetkazildi / o'qildi statistikasi; eslatmalar (cron), to'lov eslatmalari,
  tasdiqlash so'rovlari (ota-ona ilovada javob beradi).

### S5 — School Mode
- Siyosat → bog'langan bolalar qurilmasiga `Routine` (SCHOOL) / `Schedule`
  (dars vaqtlari, tanaffusda yumshatish), istisnolar, favqulodda rejim,
  qurilma holatlari (mavjud bola qurilma holatidan).

### S6 — Dashboard, bildirishnomalar markazi, hisobotlar, qidiruv

### S7 — G'amxo'rlik, psixologik testlar, rivojlanish
- So'rovnomalar va testlar bola ilovasida yechiladi; xom javoblar
  shifrlangan (AES-GCM, kalit env'da); ballar serverda.
- Maxfiylik serverda: psixolog — hammasi; sinf rahbari — o'z sinfi
  (daraja); direktor/admin — faqat agregat, K=5 atomlar (ayirish hujumidan
  himoya). Audit'da ism yo'q.

### S8 — Maktab uchun Growth
- Sinf faolligi Daily Learning natijalaridan (ota-ona roziligi bilan),
  materiallar va topshiriqlar.

## 3. Har bosqich "tayyor" mezoni
- `npm run build`, unit + e2e testlar yashil; yangi kod 80%+ qoplangan.
- Migratsiya bo'sh bazada ham, mavjud sxema ustida ham qo'llanadi.
- Swagger'da hujjatlangan; panel / ilova adapteri o'sha bosqich
  endpointlariga ulangan va tekshirilgan.
- Commit branch'ga; `main`ga merge / deploy — faqat foydalanuvchi ruxsati
  bilan.

## 4. Qarorlar (standart — o'zgartirish mumkin)
- Demo panel (`/school/`) mock rejimda qoladi; haqiqiy rejim env bayroq
  bilan, pilot boshlanganda yoqiladi.
- Xabarlar — avval push; SMS (pullik) keyinroq, maktab sozlamasi bilan.
- Daily Learning DON — fan bo'yicha kunlik birinchi urinishga.
- Ota-ona bolaning sinf / fanlarini ham o'zgartira oladi.
