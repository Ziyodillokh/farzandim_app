# Backend rejasi: Parvoz Growth (Daily Learning) va Parvoz School

Holat: 2026-10-20 (bajarilganlar — 5-bo'limda). Branch: `feat/learning-school-backend` (worktree
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

## 5. Bajarilganlar (2026-10-20)

Barcha ishlar `feat/learning-school-backend` branch'ida, `main`ga merge /
deploy qilinmagan. Har bosqich: backend + e2e (haqiqiy Postgres) + panel
http adapteri (`NEXT_PUBLIC_DATA_SOURCE=http`).

| Bosqich | Holat | Asosiy natija |
|---|---|---|
| B0 | ✅ | e2e infratuzilma, atomik DON, Toshkent kuni, CI `backend-quality` |
| G1 | ✅ | Daily Learning API, adaptiv tanlov, haftalik hisobot, admin savollar |
| G2 | ✅ | bola ilovasi serverga ulandi (`feat/growth-redesign`) |
| Savollar | ✅ | 174 + 156 (2-to'lqin: 1–4 va 10–11-sinflar) |
| S1 | ✅ | maktab auth (refresh 30 s imtiyoz oynasi), tuzilma, sinflar, xodimlar, audit |
| S2 | ✅ | o'quvchilar, ota-onalar, CSV import, 360° karta, Parvoz Parents bog'lanishi |
| S3 | ✅ | davomat, HMAC kiosk QR, bola check-in, ota-ona push, kelmaganlar cron |
| S4 | ✅ | e'lonlar (yetkazish / o'qildi), eslatmalar, to'lovlar, tasdiqlash, dispatcher |
| S5 | ✅ | School Mode; Android'da virtual "Maktab" jadvallari (ilova o'zgarmaydi) |
| S6 | ✅ | bosh sahifa, bildirishnomalar, oylik hisobot, qidiruv |
| S7a | ✅ | Bola ovozi: shifrlangan javoblar, K=5 atomlar, murojaatlar, protokol |
| S7b | ✅ | psixologik testlar: kutubxona, konstruktor, import, tayinlash, bola ilovasida yechish |
| S7c | ✅ | rivojlanish: o'quvchi / sinf / maktab, e'tibor ro'yxati; direktorga faqat yakunlangan va ≥5 bolali natija |
| S8 | ✅ | sinf faolligi, qiziqishlar, materiallar, topshiriqlar |

Xavfsizlik ko'rigi (1-bosqich): HIGH / MEDIUM topilmalar tuzatilgan,
regressiya testlari — `school-review-fixes.e2e-spec.ts`. Vaqtinchalik parol
almashtirilguncha server boshqa so'rovlarni 403 qiladi.

Xavfsizlik ko'rigi (2-bosqich: S6, S7b, S7c, S8) — hammasi tuzatilgan,
regressiya testlari — `school-review-fixes-2.e2e-spec.ts`:
- **Himoyalangan rollar** (psixolog): direktor ularni yarata, ularga ko'tara
  yoki ularning login / parolini o'rnata olmaydi — faqat operator
  (`scripts/school/create-staff.ts`). Pasaytirish va hisobni o'chirish mumkin.
  Rol tekshiruvi qulflangan qatorda (`FOR UPDATE`) — parallel so'rovlar bilan
  chetlab o'tilmaydi. O'z hisobiga `setAccount` yo'q: o'z paroli faqat joriy
  parol bilan (profil).
- **So'rov hajmi:** JSON / urlencoded ≤ 5 MB (avval 100 MB, auth'dan oldin
  o'qilardi). Kattaroq kerak bo'lsa — endpointda `@BodyLimit` (bola
  qurilmasining ilovalar ro'yxati: 48 MB). Fayllar (multipart) — o'z chegarasi.
- **Growth K=5:** natijalar (topshiriq, ball, DON) faqat ≥5 faol bolali
  (sinf, hafta) kataklaridan va faqat YAKUNLANGAN haftalardan; kichik guruh
  `suppressed`. Davom etayotgan hafta — faqat faollar soni (`current`): jonli
  katak har urinishda o'zgarib, ikki o'qish farqi bolaning natijasini ochardi.
  Jami, sinf filtri, oylik hisobot (dushanbasi shu oyda bo'lgan yakunlangan
  haftalar), bosh sahifa va profil konteksti bir xil bo'linishda — ayirib
  tiklab bo'lmaydi. Sinf — urinish yakunlangan paytdagi snapshot
  (`learning_attempts.school_class_id`, faqat o'sha haftada boshlangan
  urinishga): o'quvchini ko'chirish yoki uzish o'tgan haftalarni
  o'zgartirmaydi, bog'lashdan oldingi faollik maktabga ko'rinmaydi.
  Qiziqishlarda 5 nafardan kam bolali daraja ko'rsatilmaydi.
- **Rivojlanish:** sinf rahbariga hissiy soha o'rtachalari ham yo'q (sinf va
  sinfdoshlar o'rtachasini ayirib yashirin indeks tiklanardi).
- **Kichiklari:** ota-onani uzish — sinf rahbari faqat hamma faol farzandi
  o'z doirasida bo'lsa; test natijalari — o'quvchining bugungi sinfi
  (arxivlanganlar yo'q); faol tayinlashli testda savol / shkala o'zgarmaydi va
  arxivlanmaydi (409; vaqt chegarasi uzaytirilsa — kattasi bo'yicha); erta
  ketish lentasi — tarix ruxsatisiz faqat bugungi, sabab faqat
  `attendance.earlyExit` egasiga; natija (tayinlash, o'quvchi) unikal indeksi.

**Qolgan ishlar:**
- Parvoz Parents ilovasi: taklif kodi, e'lonlar, davomat, erta ketish, to'lovlar.
- Parvoz Growth ilovasi: kiosk QR skaner, so'rovnoma va murojaat, psixologik
  test, maktab topshiriqlari.
- Production: `SCHOOL_DATA_KEY` (32 bayt base64) env'ga qo'shilishi kerak —
  aks holda Bola ovozi / testlar yozuvi 503.
- Pilot: `scripts/school/create-school.ts` bilan maktab, panel http rejimda.

## 6. Deploy va pilot yo'riqnomasi

`main`ga merge = production deploy: `deploy-test.yml` (backend — avval
`backend-quality` darvozasi: unit + e2e Postgres'da) va `deploy-landing.yml`
(sayt, `/school` demo va `/maktab` haqiqiy panel). Faqat egasining ruxsati
bilan. Repo OMMAVIY — CI loglari hammaga ko'rinadi (parol va kalitlar logga
chiqmaydi; quyidagi jarayonlar shunga qurilgan). Store'dagi ilovalar bilan
moslik tekshirilgan: mavjud endpointlar shakli o'zgarmagan.

1. **`SCHOOL_DATA_KEY`** — 32 bayt, base64 (`openssl rand -base64 32`). Bola
   ovozi javoblari, murojaatlar va psixologik test javoblari shu kalit bilan
   shifrlanadi; yo'qolsa ma'lumotni ochib bo'lmaydi. GitHub secret
   `SCHOOL_DATA_KEY` → deploy qadami uni server `.env`ga FAQAT yo'q bo'lsa
   qo'shadi (mavjudini hech qachon almashtirmaydi; nusxa:
   `~/new-platform/secrets/`). Noto'g'ri formatdagi kalit deploy'ni
   to'xtatadi (aks holda butun API yiqilardi). Kalitning asosiy nusxasi —
   egasining parol menejerida. `SCHOOL_JWT_SECRET` qo'ymang (yo'q bo'lsa
   `JWT_ACCESS_SECRET`dan hosila olinadi; 32 belgidan qisqasi API'ni yiqitadi).
2. **Deploydan oldin** CI bazaning zaxira nusxasini oladi
   (`~/new-platform/backups/`, oxirgi 5 ta) va PostgreSQL ≥ 12 ni tekshiradi.
3. **Migratsiyalar** — 10 ta, hammasi qo'shuvchi (DROP / RENAME / DELETE
   yo'q): learning (4), school core / wave2 / session grace, savollar
   2-to'lqin, psixologik natija unikal indeksi va Growth urinishi sinf
   snapshot'i (nullable ustun + indeks) — ikkalasi shu tarmoqdagi jadvallarda.
4. **Rollback:** `rollback/pre-school` branch'i (oldingi production
   commit'i) → `gh workflow run deploy-test.yml --ref rollback/pre-school -f
   component=backend`. Diqqat: yangi Growth ilovasi ishlatilgach
   (`LEARNING_REPORT` / `DAILY_LEARNING` yozuvlari) eski kod ularni o'qiy
   olmaydi — shundan keyin faqat oldinga tuzatish.
5. **Maktab, direktor, psixolog** — SSH'siz, `school-operator.yml`
   (Actions → School operator): `create-school`, `create-psychologist`,
   `reset-staff` (`staff_id`, `reset_2fa`). Vaqtinchalik parol operatorning
   bir martalik RSA-3072 ochiq kaliti bilan shifrlanadi (yo'riqnoma workflow
   faylining boshida); birinchi kirishda almashtirish majburiy. Kiritilgan
   kod / F.I.Sh. / login ommaviy logda ko'rinadi — keyin `gh run delete`.
   Serverda to'g'ridan-to'g'ri: `npx tsx scripts/school/create-school.ts` va
   `create-staff.ts` (`--reset`, `--id`, `--reset-2fa`).
6. **Haqiqiy panel:** https://farzandimedu.uz/maktab/ (CI:
   `NEXT_PUBLIC_DATA_SOURCE=http NEXT_PUBLIC_API_BASE=/api
   PANEL_BASE_PATH=/maktab`). Demo `/school` mock rejimda qoladi; ikkalasining
   brauzer xotirasi alohida (`parvoz-school:` / `parvoz-maktab:`). Refresh
   cookie `/api/school/auth` yo'lida, SameSite=Strict — panel va API bir saytda.
7. **Tekshiruv:** direktor kiradi → parolni almashtiradi → sinflar →
   o'quvchilar (CSV) → xodimlar → ota-onalarga taklif kodlari → kiosk.
8. **Ilovalar:** store'dagi Android va iOS bola ilovalarida School Mode
   yangilanishsiz ishlaydi (virtual "Maktab" jadvallari; iPhone uchun har
   kuni 06:30 da jim sinxron push). Ota-ona ilovasidagi maktab bo'limi va
   bola ilovasidagi QR / so'rovnoma / test / topshiriq ekranlari —
   `feat/school-apps` branch'ida (test APK'lar; store'ga alohida chiqariladi).
