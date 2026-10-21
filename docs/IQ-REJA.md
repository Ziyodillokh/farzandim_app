# Parvoz IQ test — reja va API shartnomasi

Bola ilovasidagi (Parvoz Growth) "IQ test": Raven uslubidagi rasmli
matritsalar, yosh bo'yicha darajalar, xalqaro amaliyotga mos baholash
(Rasch/1PL, yosh normalari, 100±15). **Skrining, tashxis emas.**

Egasining qarorlari (2026-10-21):
- Natijani **bola ham, ota-ona ham to'liq** ko'radi.
- Norma yetarli bo'lguncha natija **"taxminiy"**: persentil + daraja; IQ raqami
  (standart ball) faqat `NORMED` holatda.
- 1-bosqich: bola ilovasi + backend + ota-ona kartasi. Maktab orqali yuklash —
  2-bosqich (§7), tizim unga tayyor.

## 1. Darajalar va normalar

| Daraja | Yosh (to'liq) | Forma |
|---|---|---|
| 1 | 9–10 | `L1A`, `L1B` |
| 2 | 11–12 | `L2A`, `L2B` |
| 3 | 13–14 | `L3A`, `L3B` |
| 4 | 15–16 | `L4A`, `L4B` |
| 5 | 17–20 | `L5A`, `L5B` |

- Yosh — Kelajak'dagi `childAge` (birthDate → Toshkent kuni, aks holda `age`),
  fallback yo'q: `AGE_REQUIRED` / `AGE_OUT_OF_RANGE` (9 dan kichik, 20 dan katta).
- Har forma 20 savol, osondan qiyinga (`b` o'sishi bo'yicha). Qo'shni darajalar
  6 tadan umumiy (anchor) savolga ega. Har darajada 8 ta zaxira (`forms = []`).
- **Norma guruhlari** (to'liq yosh, yakunlash kuni): `9`, `10`, … `16`, `17-20`.
- Qayta topshirish: oxirgi yakunlangandan **180 kun** keyin, forma almashadi
  (A → B → A). Normaga faqat bolaning **birinchi** yakunlangan sessiyasi kiradi.
- Ochiq sessiya 24 soat ichida davom ettiriladi, keyin `ABANDONED`.

## 2. Ma'lumotlar modeli (Prisma)

```
IqItem      id, externalId (unique, "iq-L1-001"), level 1..5, forms String[]
            ("L1A","L2A" — anchor ikki formada), gridSvg Text,
            options Json [{key:"A"..."F", svg}], answer Char(1) — SIR (hech
            qachon klientga yuborilmaydi), b Float (Rasch qiyinligi, logit),
            rule String, active Bool
IqSession   id, childId, level, form, ageYears (boshlangandagi), status
            STARTED|IN_PROGRESS|COMPLETED|ABANDONED, itemIds String[] (tartib
            snapshot), total, firstAttempt Bool, normGroup String?,
            result Json? (FAQAT xom: {correct, total, responses: number[]}),
            scoringVersion Int?, startedAt, completedAt
IqAnswer    id, sessionId, itemId, position, choice Char(1), correct Bool,
            durationMs Int?, answeredAt — unique(sessionId,itemId)
IqNorm      group (PK: "9".."16","17-20"), n, mean, m2 (Welford, θ bo'yicha),
            updatedAt
```

Standart ball, persentil, daraja **saqlanmaydi** — o'qilganda hisoblanadi
(item `b` yoki norma o'zgarsa natijalar darhol qayta baholanadi).

## 3. Baholash (backend/src/modules/iq/domain/scoring.ts — sof funksiyalar)

1. **Qobiliyat θ** — Rasch (1PL): `P(to'g'ri) = 1 / (1 + e^-(θ-b))`.
   EAP baholash, prior N(0,1), kvadratura θ∈[-5,5] qadam 0.05.
   `se` = posterior SD.
2. **Norma** — guruh `IqNorm` (n, mean, sd = √(m2/(n-1))):
   - `n < 30` → **dastlabki ma'lumotnoma**: mean = guruh dizayn o'rtachasi
     (darajaning kichik yoshi −0.25, katta yoshi +0.25, 17-20 → 0), sd = 1.
   - `n ≥ 30` → empirik mean/sd.
3. `z = (θ − mean) / sd`; `percentile = Φ(z)·100` (1..99);
   `standard = 100 + 15z` (55..145 oralig'ida), `ci95 = 100 + 15·(z ± 1.96·se/sd)`.
4. **Holat**: `n ≥ 300` → `NORMED` (standart ball + ci95 ko'rsatiladi),
   aks holda `PROVISIONAL` (`standardScore = null`, `ci95 = null`).
5. **Daraja** (WISC-V tasnifi, standart ball bo'yicha; PROVISIONAL'da ham):
   `VERY_HIGH` ≥130, `HIGH` 120–129, `ABOVE_AVERAGE` 110–119,
   `AVERAGE` 90–109, `BELOW_AVERAGE` 80–89, `LOW` 70–79, `VERY_LOW` <70.
   Ilovada yumshoq matn (masalan `LOW`/`VERY_LOW` → "Rivojlanish zonasi");
   har doim "Skrining, tashxis emas" izohi.
6. Normani yangilash — yakunlashda (birinchi urinish bo'lsa) shu
   tranzaksiyada Welford bilan. To'liq qayta hisoblash: `scripts/iq/rebuild-norms.ts`.

## 4. Bola API (`Roles('CHILD')`, prefix `/iq`)

```
GET  /iq/overview
  → { age: {status:"OK"|"AGE_REQUIRED"|"AGE_OUT_OF_RANGE", age, level|null},
      canStart: bool, nextAvailableAt: ISO|null,
      active: {sessionId, answered, total} | null,
      last: ResultView | null,
      history: [{sessionId, completedAt, level, result: ResultView}] }

POST /iq/sessions                      → SessionView   (yangi yoki davom etayotgan)
  409 {code: AGE_REQUIRED | AGE_OUT_OF_RANGE | RETAKE_TOO_SOON, nextAvailableAt?}
GET  /iq/sessions/:id                  → SessionView
PUT  /iq/sessions/:id/answers/:itemId  body {choice:"A".."F", durationMs?:int}
  → { answeredCount, total, status }   (to'g'ri/noto'g'ri QAYTARILMAYDI)
  409 SESSION_CLOSED, 400 ITEM_NOT_IN_SESSION | INVALID_CHOICE
POST /iq/sessions/:id/complete         → SessionView (idempotent)
  400 {code: UNANSWERED, remaining: itemId[]}
```

```
SessionView = {
  id, status, level, form, total, startedAt, completedAt|null,
  items: [{ id, position, gridSvg, options: [{key, svg}], choice: "A".."F"|null }],
  result: ResultView | null            // faqat COMPLETED
}
ResultView = {
  correct, total, status: "PROVISIONAL" | "NORMED",
  percentile, band, standardScore: int|null, ci95: [lo, hi] | null,
  normGroup, completedAt
}
```

## 5. Ota-ona API (`Roles('PARENT')`)

```
GET /children/:childId/iq/summary
  → { age: {...}, last: ResultView|null, nextAvailableAt: ISO|null,
      history: [{sessionId, completedAt, level, result: ResultView}] }
```
Ota-ona to'liq natijani ko'radi, lekin savollar va bolaning javoblari yo'q.

## 6. Savollar banki

- Generator: `backend/scripts/iq/generator.py` (Python 3, faqat stdlib) —
  rasmlar noldan chiziladi (original, litsenziyasiz). Har savol avtomatik
  tekshiriladi: 6 variant noyob, to'g'ri javob bitta.
- `python3 scripts/iq/generator.py --json prisma/data/iq/items.json`
  → `npx ts-node scripts/iq/build-bank-migration.ts` → migratsiya SQL
  (`ON CONFLICT (external_id) DO NOTHING`).
- Boshlang'ich `b` — dizayn bo'yicha (daraja + qiyinlik). Ma'lumot yig'ilgach
  Rasch kalibrovkasi bilan yangilanadi (2-bosqich).

## 7. Maktab orqali IQ (2026-10-21, qilindi)

Egasining qarorlari: natijani ism bilan **psixolog va o'z sinfi rahbari** ko'radi;
maktab tayinlovi **umumiy tarixga** (180 kunlik cheklov, norma) hisoblanadi;
rozilik — `PARENTS_INFORMED` (boshqa psixologik testlar kabi).

- **Tayinlash:** psixolog `POST /school/assessments/assignments` bilan
  `testId: "parvoz-iq"` (savollar IQ bankida, maktab testlari omborida emas);
  sinflar — har qanday parallel (yoshni IQ moduli tekshiradi, 9–20).
- **Bola:** `GET /child/school/assessments` ro'yxatida `{testId: "parvoz-iq",
  kind: "IQ", itemCount: 20}` — bola oynada (ochilishdan 180 kun oldin →
  hozir) IQ testni yakunlamagan bo'lsa. Bosilganda odatdagi `/iq` oqimi;
  `IqSession`ga yangi ustun yo'q (umumiy tarix).
- **Natija:** tayinlov natijasi — bolaning oynadagi eng so'nggi yakunlangan
  sessiyasi. `GET /school/assessments/iq/results?classId=` → `{classId,
  className, mode: INDIVIDUAL|AGGREGATE, students, linked, completed, bands,
  suppressed, rows: [{studentId, name, linked, result: ResultView|null}]}`.
  - psixolog (`assessments.manage`) — har qanday sinf, ism bilan;
  - sinf rahbari (`development.individual`) — faqat o'z sinfi, ism bilan;
  - direktor / admin (`development.view`) — faqat `bands`, 5 dan kam — yashirin.
- **Panel:** "Tayinlash" oynasida "Parvoz IQ" (faqat `/maktab`), Rivojlanish →
  "Parvoz IQ" tabi (psixolog), sinf rahbari va direktorga sahifa pastida.

### Keyin
- Natijani `development` REASONING sohasiga ulash.
- Admin: savollar sahifasi, `b` kalibrovkasi, norma holati.
- Moslashuvchan (CAT) test.
