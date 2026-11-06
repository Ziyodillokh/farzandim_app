# "Men" bo'limi — DON daftari, yutuqlar, haftalik faollik (I02, I03, I06) backend kontrakti

Branch: `feat/men-don-api` (origin/main'dan). Migratsiya: **`20261108090000_men_don`**
(faqat qo'shuvchi: `child_profiles.achievement_dates JSONB NOT NULL DEFAULT '{}'`; mavjud qatorlar o'zgarmaydi).

Parvoz Growth bola ilovasining "Men" bo'limi uchun uch blok: **A** DON daftari (I03), **B** yutuqlar (I06),
**C** haftalik o'quv faolligi (I02). Hamma yo'l `/api` prefiksi bilan.

> **DON miqdorlari va mukofot qoidalari O'ZGARMAGAN** (egasining qarori kutilmoqda): yangi DON manbasi yo'q,
> chegara (cap) yo'q, `applyAward` summalari o'zgarmagan, ota-onaning `POST /children/:childId/xp-events` yo'li
> avvalgidek. Yutuqlar DON ham, XP ham bermaydi.

## 0. Umumiy qoidalar

- `Authorization: Bearer <consumer JWT>`; tokensiz → `401`.
- **A va B** (`/children/:childId/...`): "bola yoki ota-ona" — mavjud gamification yo'llari bilan bir xil qoida
  (`assertChildAccess`): bolaning o'z foydalanuvchisi yoki uning ota-onasi. Begona foydalanuvchi (boshqa ota-ona,
  boshqa bola) → `403`; bola topilmasa → `404`.
- **C** (`/learning/weekly`): faqat `CHILD` tokeni, faqat o'z ma'lumoti. Ota-ona tokeni → `403`.
- Xatolar: `{ "statusCode": 400, "message": "...", "code": "VALIDATION" }` (kursor), validatsiya xatolari
  (`limit`) — standart `400` (`ValidationPipe`).
- Sana/vaqt: `...At` / `at` — ISO-8601 (UTC); kun — Toshkent (UTC+5) `YYYY-MM-DD`.

## A. DON daftari (I03)

### `GET /api/children/:childId/don-ledger?cursor=&limit=`

`limit` 1–100 (default **50**; `0`, `101`, `abc`, `1.5` → `400`). `cursor` — oldingi javobdagi `nextCursor` (opaque).
Noma'lum so'rov parametri → `400`. Buzilgan kursor → `400 { "code": "VALIDATION", "message": "cursor: invalid" }`.

```json
{
  "balance": 480,
  "pending": 0,
  "items": [{
    "id": "7f0c…", "kind": "LEARNING", "amount": 16, "status": "CONFIRMED",
    "at": "2026-11-05T09:12:00.000Z", "subject": "math", "title": null, "relatedId": "<attemptId>"
  }],
  "nextCursor": "eyJ0Ijoi…"
}
```

- **Manba:** `XpEvent` qatorlari, `donDelta != 0` (manfiy ham — `OTHER` sifatida). XP-only va 0/0 yozuvlar chiqmaydi.
- `balance` = `ChildProfile.donBalance` (profil bo'lmasa `0`). `pending` hozircha doim `0`, har `status` = `"CONFIRMED"`
  (kutilayotgan DON qoidalari qarori uchun zaxira).
- Eng yangisi birinchi. Har elementda 8 ta kalit doim bor (`subject`/`title`/`relatedId` — mos kelmasa `null`).

#### `kind` xaritasi

| Manba (`XpEvent.type`) | `kind` | `subject` | `title` | `relatedId` |
|---|---|---|---|---|
| `DAILY_LEARNING` | `LEARNING` | urinishning fani, kichik harf (`math`) | `null` | `attemptId` |
| `DAILY_GOAL` (qadam) | `STEPS` | `null` | `null` | `null` (guruh, quyida) |
| `CONTEST_JOIN` | `OLYMPIAD` | `null` | olimpiada sarlavhasi | `olympiadId` |
| `CONTEST_WIN` | `OLYMPIAD` | `null` | urinish → olimpiada sarlavhasi | `attemptId` |
| `BOOK_READ` | `BOOK` | `null` | audiokitob, topilmasa kitob sarlavhasi | audiokitob/kitob id |
| `OTHER` + `relatedId` = mavjud video id | `VIDEO` | `null` | video sarlavhasi | `videoId` |
| qolgani (`OTHER`, `CREATIVE_*`, `COURSE_LESSON`, `STREAK_WEEKLY`, `CONTENT_POST`) | `OTHER` | `null` | `null` | yozuvdagi qiymat |

Sarlavha/fan **topilmasa** (o'chirilgan kontent, noma'lum `relatedId`) — `null`, element baribir chiqadi.
Video tugatish `OTHER` turi bilan yoziladi (`completeVideo`), shuning uchun VIDEO faqat `type = OTHER` va `relatedId`
videoga mos kelganda. `LEARNING` fani va olimpiada urinishi **faqat shu bolaning** urinishlaridan olinadi
(boshqa bolaning urinish id'si yozuvga tushib qolsa ham ma'lumot oshkor bo'lmaydi).

> Eslatma: ota-ona `POST /xp-events` bilan `DAILY_GOAL` turida DON bersa, u ham `STEPS` guruhiga tushadi
> (qadam mukofoti bilan tur bo'yicha ajratib bo'lmaydi). Hozircha qabul qilingan.

#### Qadam (STEPS) guruhi

Bir Toshkent kunidagi (yozuvning `createdAt`i bo'yicha, `donDelta != 0`) barcha `DAILY_GOAL` qatorlari **bitta**
elementga: `id = steps:YYYY-MM-DD`, `amount` = kun yig'indisi, `at` = kunning **oxirgi** qatori vaqti.
Toshkent kunining chegarasi UTC 19:00 (`2026-11-03T18:59:59Z` — 03-kun, `19:00:00Z` — 04-kun).

#### Kursor qanday ishlaydi (guruhlarga qaramay to'g'ri)

1. Har elementning **langari** bor — uning o'rnini belgilovchi xom qator `(createdAt, id)`. Oddiy yozuvda — o'zi;
   qadam kunida — kunning ENG SO'NGGI qadam qatori. Tartib: langar bo'yicha kamayish.
2. `nextCursor` = sahifadagi **oxirgi elementning langari** (`base64url({"t": ISO, "i": rowId})`, opaque deb qarang).
   Keyingi sahifa: `(createdAt, id) < kursor` xom qatorlari.
3. Server xom qatorlarni partiyalab o'qiydi (indekslangan `(child_id, created_at DESC)`), qadam qatori **faqat o'zi
   kunning langari bo'lsa** element beradi (yig'indi kunning hamma qatoridan, bitta indekslangan oraliq so'rov bilan);
   kunning eski qatorlari o'tkazib yuboriladi. Shu sabab kun ikki sahifada takrorlanmaydi va yo'qolmaydi, hatto
   uning eski qatorlari kursordan pastda, boshqa yozuvlar bilan aralash bo'lsa ham.
4. Teng `createdAt` bo'lsa `id` bo'yicha aniq tartib. Yangi yozuvlar (kursordan yuqorida) eski sahifalarni siljitmaydi;
   allaqachon ko'rsatilgan kunga yangi qadam kelsa, u keyingi yangilashda tepaga chiqadi (eski sahifada takror bo'lmaydi).
5. `nextCursor` — faqat keyingi sahifada kamida 1 element bo'lsa; oxirgi sahifada `null`.

Xotira: butun daftar yuklanmaydi — har so'rov `limit + 1` element uchun indeks bo'yicha partiya o'qiydi, sarlavhalar
sahifa uchun guruhlab (manbaga bitta so'rov) olinadi.

## B. Yutuqlar (I06)

### `GET /api/children/:childId/badges`

```json
{ "items": [
  { "id": "streak_7",     "earned": true,  "earnedAt": "2026-11-05T09:12:00.000Z" },
  { "id": "streak_30",    "earned": false, "earnedAt": null },
  { "id": "first_book",   "earned": true,  "earnedAt": null },
  { "id": "olympian",     "earned": false, "earnedAt": null },
  { "id": "topic_master", "earned": false, "earnedAt": null },
  { "id": "thinker",      "earned": false, "earnedAt": null }
] }
```

Tartib — katalog tartibi (yuqoridagi). Katalog serverda konstanta (`badge-catalog.ts`), id'lar barqaror.

| id | Shart |
|---|---|
| `streak_7` | 7 kunlik streak (`ChildProfile.streakDays` ≥ 7) |
| `streak_30` | 30 kunlik streak (`streakDays` ≥ 30) |
| `first_book` | birinchi kitob (audiokitob tugatildi — mavjud mantiq; ma'lumotdan: `BOOK_READ` yozuvi bor) |
| `olympian` | olimpiadaga qo'shildi (`POST /content/olympiads/:id/start`; ma'lumotdan: `OlympiadAttempt` bor) |
| `topic_master` | birinchi mavzu o'zlashtirildi (pastda) |
| `thinker` | Parvoz IQ testi yakunlandi (`COMPLETED` sessiya) |

- **Saqlash:** ochilgan id'lar `ChildProfile.achievements` (mavjud JSON ro'yxat, o'zgarmagan shakl — bola ilovasi
  `unlockedAchievements` ni shundan o'qiydi). Ochilgan vaqt — yangi `ChildProfile.achievementDates`
  (`{ "<id>": "<ISO>" }`). Profil javoblariga (`GET /children/:id/profile`, `profile:updated`) shu maydon qo'shimcha
  bo'lib chiqadi — eski ilovalar e'tiborsiz qoldiradi.
- **Voqea bo'yicha ochish** (`earnedAt` = ochilgan lahza):
  - `streak_7` / `streak_30` — `applyAward` ichida, streak yangilangan **o'sha tranzaksiyada** (kunlik test, kontent,
    olimpiada, qadam sinxroni va h.k.); alohida so'rov yo'q.
  - `first_book` — mavjud: audiokitob tugatilganda (`unlockAchievement`).
  - `olympian` — olimpiadani boshlashda (ishtirok mukofoti bilan birga; DON/XP summasi o'zgarmagan).
  - `thinker` — IQ sessiyasini yakunlashda (`POST /iq/sessions/:id/complete`; xato yakunlashni buzmaydi).
  - `topic_master` — mavzu bo'yicha urinish yakunlanganda shu mavzu "o'zlashtirilgan" bo'lsa.
- **Kechiktirilgan to'ldirish (backfill):** `GET` har chaqirilganda hali ochilmagan yutuqlar mavjud ma'lumotdan
  tekshiriladi va topilganlari ochiladi (**idempotent**: qayta chaqiruv takrorlamaydi). Bunday yutuqlarda
  `earned: true`, `earnedAt: null` (vaqt noma'lum). Eski `first_book` ham shunday (`null`).
- **`topic_master` tanlovi:** mavzular katalogi mavjud, shuning uchun u ishlatiladi (kunlik "mukammal urinish" emas):
  mavzu **o'zlashtirilgan** = mavzuga bog'langan savollarga yakunlangan urinishlardagi eng so'nggi ≤10 javob ichida
  kamida 5 ta dalil va ≥80% to'g'ri (`domain/topic-mastery.ts` — bilim xaritasi bilan **bir xil** qoida va bir xil
  SQL so'rov, `learning-mastery.query.ts`). Ochilgan yutuq keyin mavzu "qayta pasaysa" ham saqlanadi.
- **Parallel xavfsizlik:** ochish bola mukofotlari qulfi (`pg_advisory_xact_lock xp:<childId>`) ostida o'qib-yoziladi —
  parallel voqealar bir-birining yutug'ini yo'qotmaydi (avval `unlockAchievement` qulfsiz o'qib-yozardi).
- **Mazmun:** katalogda yo'q eski id'lar `achievements`da saqlanadi, javobga chiqmaydi.
- **Narx:** backfill faqat hali ochilmagan yutuqlar uchun so'rov beradi (eng og'iri `topic_master` — bolaning
  yakunlangan javoblari bo'yicha bitta oyna so'rovi); "Men" ekrani ochilganda bir marta chaqirish yetarli.

## C. Haftalik o'quv faolligi (I02)

### `GET /api/learning/weekly` (CHILD)

Joriy va oldingi ISO hafta (dushanba–yakshanba, Toshkent). **Eskisi birinchi.**

```json
{ "weeks": [
  { "weekStart": "2026-10-26", "sessions": 5, "minutes": 52, "activeDays": 4, "streak": 4 },
  { "weekStart": "2026-11-02", "sessions": 7, "minutes": 68, "activeDays": 5, "streak": 7 } ],
  "firstWeek": false }
```

- `weekStart` — haftaning dushanbasi (`YYYY-MM-DD`, Toshkent).
- `sessions` — haftada **yakunlangan** (`COMPLETED`) urinishlar soni (tugallanmagan/tashlab ketilgani hisoblanmaydi).
- `minutes` — `round( Σ min(davomiylik, 60 daqiqa) / 60 )`; davomiylik = `completedAt − startedAt` (natijadagi
  `durationSeconds` bilan bir xil). **Har urinish 60 daqiqa bilan cheklanadi** (ochiq qolib ketgan urinish uchun);
  yig'indi bir marta yaxlitlanadi.
- `activeDays` — kamida 1 ta yakunlangan urinish bor turli Toshkent kunlari soni.
- `streak` — **hafta oxirigacha** o'quv streak'i (joriy hafta: bugungacha), `learning-stats.ts` qoidasi bilan: asOf kun
  (hafta oxiri / bugun) yechilgan bo'lsa shundan, yechilmagan bo'lsa kechadan orqaga ketma-ket kunlar
  (`streakFromDays` — `learningStreak` shundan foydalanadi). Streak hafta chegarasidan o'tib davom etadi.
  (Bu o'quv-test streak'i; yutuqlardagi `streak_7/30` esa umumiy `ChildProfile.streakDays`.)
- `firstWeek` — joriy haftadan oldin yakunlangan urinish **yo'q** (umuman urinishi yo'q bola ham `true`).
- Urinishning "kuni" — `LearningAttempt.day` (boshlangan Toshkent kuni; ota-ona hisoboti va streak ham shunday).
- So'rovlar: ikki haftalik urinishlar (`child_id, day` indeksi) + bolaning faol kunlari `GROUP BY day` (qatorlar emas).

## D. O'zgargan fayllar (qisqacha)

- Yangi: `gamification/{child-access,child-award-lock}.ts`, `gamification/badges/*`, `gamification/ledger/*`,
  `gamification/dto/don-ledger-query.dto.ts`, `learning/learning-weekly.service.ts`, `learning/domain/learning-weekly.ts`,
  `learning/learning-mastery.query.ts`.
- O'zgargan (xatti-harakat saqlangan): `GamificationService` (streak yutuqlari `applyAward` ichida; `unlockAchievement`
  endi qulf ostida va vaqtni yozadi), `IqService` (+`thinker`), `ConsumerOlympiadsService` (+`olympian`),
  `LearningService` (+`topic_master`), `LearningTopicsService` (dalil so'rovi umumiy faylga ko'chirildi), `learning-stats.ts`
  (`streakFromDays`), `tashkent.ts` (`isoWeekStart`).
- Testlar: `gamification/**/*.spec.ts`, `learning/domain/learning-weekly.spec.ts`,
  `test/e2e/men-don-{ledger,badges,weekly}.e2e-spec.ts`.
