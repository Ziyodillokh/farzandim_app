# Daily Learning: mavzular katalogi (topics)

Holat: 2026-11-06. Branch: `feat/learning-topics` (worktree `farzandim_app-topics`). Migratsiya:
`backend/prisma/migrations/20261106090000_learning_topics` (faqat qo'shuvchi).

## 1. Nega

Bola ilovasi (Parvoz Growth) ikki yangi ekranga muhtoj:

- **U02 "Fanning bilim xaritasi"** — fan mavzulari vertikal yo'l sifatida; har birida daraja
  («Oʻzlashtirilgan» `MASTERED`, «Mashq kerak» `PRACTICE`, «Hali baholanmagan» `NOT_ASSESSED` —
  hech qachon 0% emas), joriy mavzu ajratilgan, oxirgi baholash sanasi va bajarilgan topshiriqlar soni.
- **U03 "Mavzu va mashq rejasi"** — bitta mavzu: maqsad, oldingi natija (masalan 6/10, 1-noyabr),
  «Boshlash» shu mavzu bo'yicha 10 savollik urinishni boshlaydi; yarim qolgan urinish bo'lsa
  «Davom ettirish (4/10)».

Avval `LearningQuestion.topic` erkin matnli `{uz,ru,en}` JSON edi, bankda (330 savol) har mavzuga ~1 savol.
Endi katalog (`learning_topics`) + savollarni mavzuga bog'lash (admin) bor. Mavzuda savol yetarli
bo'lmaguncha ilova eski aralash kunlik mashqqa qaytadi (`available: false`).

## 2. Ma'lumotlar

Bitta additive migratsiya (jadval, nullable ustunlar, indekslar; hech narsa o'chirilmaydi/o'zgartirilmaydi):

| O'zgarish | Tafsilot |
|---|---|
| enum `LearningTopicStatus` | `ACTIVE`, `HIDDEN` |
| jadval `learning_topics` | `id`, `subject`, `key` (slug), `title` JSON `{uz, ru?, en?}`, `goal` JSON?, `min_grade`, `max_grade`, `position`, `status`, `created_by`, vaqtlar. `UNIQUE(subject,key)`, indeks `(subject,status,position)` |
| `learning_questions.topic_id` | nullable FK, `ON DELETE SET NULL`, indeks `(topic_id,status)`. Eski `topic` JSON ustuni SAQLANADI (eski ilovalar o'qiydi) |
| `learning_attempts.topic_id` | nullable FK, `ON DELETE SET NULL`; `null` = oddiy aralash kunlik urinish. Qo'shimcha indeks `(child_id, topic_id)` |

Prisma'da relation maydoni `topicRef` (`topic` nomi eski JSON ustuniga band).

## 3. Domen qoidalari (`backend/src/modules/learning/domain/topic-mastery.ts`, sof funksiyalar)

```
MIN_TOPIC_QUESTIONS = 10   MASTERY_WINDOW = 10   MASTERY_MIN_EVIDENCE = 5   MASTERY_PERCENT = 80
```

- **Dalil (evidence)** = bolaning mavzuga bog'langan savollarga javoblari, faqat `COMPLETED` urinishlardan
  (urinish mavzu bo'yicha yoki oddiy aralash bo'lishidan qat'i nazar), yangisi birinchi, ko'pi bilan 10 ta.
- 5 tadan kam dalil → `NOT_ASSESSED`; `to'g'ri × 100 ≥ 80 × dalillar soni` → `MASTERED`; aks holda `PRACTICE`
  (butun sonlar bilan, yaxlitlashsiz: 7/9 = 77,8% = `PRACTICE`).
- Mavzu bola uchun `available`: `ACTIVE` va bola sinfini qoplaydigan kamida 10 ta FAOL savol bor.
- `currentTopicId` = `position` bo'yicha birinchi `available` va `MASTERED` bo'lmagan mavzu, yo'q bo'lsa `null`.

Boshqa sof modullar: `topic-input.ts` (kalit slug `^[a-z0-9]+(-[a-z0-9]+)*$` ≤ 80, uch tilli matn, sinf oralig'i),
`topic-backfill.ts` (backfill rejasi, slug). Hammasi unit test bilan.

## 4. Bola API (rol `CHILD`, `/api/learning/...`)

Profil bo'lmasa — mavjud xulq: `409 {code: 'PROFILE_REQUIRED'}`. Ota-ona tokeni — `403`.

### `GET /learning/subjects/:subject/topics`

Noma'lum fan → `400`. Bola sinfini qoplaydigan `ACTIVE` mavzular, `position` tartibida.

```json
{
  "subject": "math", "grade": 7, "currentTopicId": "uuid|null",
  "topics": [{
    "id": "uuid", "key": "oddiy-kasrlar",
    "title": {"uz": "Oddiy kasrlar", "ru": "…", "en": "…"},
    "goal": {"uz": "…", "ru": "…", "en": "…"},
    "position": 0, "minGrade": 5, "maxGrade": 7,
    "questionCount": 12, "available": true,
    "mastery": "MASTERED|PRACTICE|NOT_ASSESSED",
    "evidenceCount": 10, "evidenceCorrect": 9,
    "lastAssessedAt": "2026-11-01T09:10:00.000Z",
    "completedAttempts": 2,
    "lastResult": {"correct": 6, "total": 10, "completedAt": "2026-11-01T09:10:00.000Z"}
  }]
}
```

`goal` yo'q bo'lsa `null`; `lastResult` yo'q bo'lsa `null`. `title`/`goal` da yetishmayotgan `ru`/`en` `uz` bilan
to'ldiriladi (ilova doim uch tilni oladi). 5 ta agregat so'rov (profil, mavzular, savollar soni, dalillar
(`ROW_NUMBER()` oynasi), yakunlangan urinishlar) — N+1 yo'q.

### `GET /learning/topics/:topicId`

`Topic` + `"subject": "math"` + `"inProgressAttempt": {"id", "answered", "total"} | null`
(shu mavzu bo'yicha BUGUNGI yakunlanmagan urinish). Mavjud emas yoki `HIDDEN` → `404`; noto'g'ri uuid → `400`.
Bola sinfiga mos savol bo'lmasa ham qaytadi (`questionCount: 0`, `available: false`).

### `POST /learning/attempts` + `topicId`

Body: `{"subject": "math", "topicId": "uuid"}` (`topicId` ixtiyoriy). Mavzu mavjud, `ACTIVE`, `subject` ga mos va
`available` bo'lmasa → `422 {"code": "TOPIC_NOT_AVAILABLE"}`. Mavzu pulidan (faqat bola sinfiga mos FAOL
savollar) `pickQuestions` qoidasi bilan 10 savol; `topicId` urinishga yoziladi.
Oddiy (`topicId`siz) urinish — avvalgidek.

### Javoblarga qo'shilgan maydonlar (faqat qo'shimcha)

- Urinish (`POST /attempts`, `GET /attempts/:id`): `topic: {id, key, title} | null`.
- Natija (`POST …/complete`, `GET /results` elementlari, `GET …/review` → `result`):
  - `topicRef: {id, key, title} | null` — **yangi ilova shuni o'qisin**.
  - `topic` — eski maydon: oddiy urinishda eski `{uz, ru, en}` (o'zgarmagan), mavzu urinishida mavzu
    sarlavhasi `{uz, ru, en}` + `id`, `key`, `title` (eski ilovalar `topic.uz` ni o'qiyveradi).

## 5. Admin API (`/api/admin/learning/...`, ruxsat `manage_learning`, audit jurnaliga yoziladi)

| Endpoint | Izoh |
|---|---|
| `GET /topics?subject=&status=` | **oddiy massiv** `Topic[]` (o'rovchi obyektsiz); har element `questionCount` (FAOL bog'langan savollar); tartib: fan, `position`. `subject` kichik harfli (`math`, `native`, `english`, …) — bola API bilan bir xil |
| `POST /topics` | `{subject, key, title, goal?, minGrade, maxGrade, position?, status?}` → 201. `position` berilmasa fan oxiriga |
| `PATCH /topics/:id` | `key`, `title`, `goal` (`null` = o'chirish), `minGrade`, `maxGrade`, `position`, `status`. Fan o'zgarmaydi. Bo'sh tana → 400 |
| `POST /topics/reorder` | `{subject, ids}` → `position = indeks`. `ids` fanning BARCHA mavzulari (yashirinlari ham) bo'lishi shart, aks holda `400 TOPIC_ORDER_MISMATCH` (`missing`, `unknown`) va hech narsa o'zgarmaydi. Javob: yangi tartibdagi massiv (`GET /topics` bilan bir xil shakl) |
| `POST /topics/:id/questions` | `{questionIds}` → `{topicId, linked, questionCount}`. Boshqa fan savoli → `400 QUESTION_SUBJECT_MISMATCH`, yo'q savol → `400 QUESTION_NOT_FOUND`; boshqa mavzudagi savol ko'chiriladi |
| `POST/PATCH /questions` | ixtiyoriy `topicId` (mavjud va bir fan: `400 TOPIC_NOT_FOUND` / `QUESTION_SUBJECT_MISMATCH`); PATCH da `topicId: null` ajratadi |
| `GET /questions?topicId=<uuid>` | mavzu bo'yicha filtr |
| `GET /questions?topicId=none` | faqat mavzusiz savollar (`topic_id IS NULL`); `subject=` bilan birga ishlaydi. Boshqa qiymat (uuid ham, `none` ham emas) → 400. Har savol qatorida `topicId` bor (bog'lanmagan bo'lsa `null`) |
| `POST /questions/import` | ixtiyoriy `topicId` — import qilingan yangi (va `existing: 'update'` bilan yangilangan) savollar shu mavzuga bog'lanadi |

Validatsiya: sinf 1–11 va `minGrade ≤ maxGrade`; kalit slug; `title.uz` bo'sh emas (`ru`/`en` ixtiyoriy,
noma'lum til kaliti rad etiladi); `title` ≤ 80, `goal` ≤ 300 belgi; `(subject,key)` takrori → `409 TOPIC_KEY_TAKEN`.
Qattiq o'chirish YO'Q — mavzu `HIDDEN` qilinadi (bola ilovasidan yo'qoladi, urinishlar tarixi saqlanadi).
`reorder` va `…/questions` `200` qaytaradi (resurs yaratmaydi).

## 6. Qarorlar (sharhga muhtoj bo'lishi mumkin)

1. **`results.topic` to'qnashuvi.** Shartnoma natija elementlariga `topic: {id,key,title}` deydi, lekin natijada
   `topic` allaqachon eski `{uz,ru,en}` (hozirgi ilova o'qiydi). Eski shaklni buzmaslik uchun: `topic` —
   eski + mavzu urinishida `id/key/title` kengaytmasi; toza shakl — yangi `topicRef`. Urinish javobida
   (`AttemptView`) `topic` yangi maydon, shuning uchun u to'g'ridan-to'g'ri `{id,key,title}|null`.
2. **Mavzu urinishi ham kunlik qoidaga kiradi.** `isDaily` formulasi o'zgarmadi: fan bo'yicha kunning birinchi
   urinishi (profil fani bo'lsa) — mavzu bo'yicha bo'lsa ham DON/XP oladi; keyingilari amaliyot (DON yo'q).
3. **Davom ettirish mavzu bo'yicha.** Bugungi yakunlanmagan urinish `topicId` bo'yicha qidiriladi:
   mavzu urinishi oddiy urinishni (va aksincha) "davom ettirib" yubormaydi; ikkalasi bir vaqtda ochiq bo'lishi mumkin.
   O'tgan kunlarning yarim qolgan urinishlari avvalgidek `ABANDONED` bo'ladi.
4. **Moslashuvchan qiyinlik.** Mavzu urinishida so'nggi natijalar avval shu mavzu bo'yicha, yo'q bo'lsa fan
   bo'yicha olinadi (yangi mavzuni 1-qiyinlikdan boshlamaslik uchun).
5. **`lastAssessedAt`** = eng so'nggi dalil javobi vaqti (oddiy aralash urinishdagi ham); `lastResult` va
   `completedAttempts` esa faqat shu mavzu bo'yicha yakunlangan urinishlar. `NOT_ASSESSED` mavzuda 1–4 dalil
   bo'lsa `lastAssessedAt` bo'sh bo'lmasligi mumkin — ilova ko'rsatmasligi ham mumkin.
6. **`available` mavzuning o'z `minGrade/maxGrade`iga bog'liq emas**, faqat savollar sinfiga (shartnoma
   ta'rifi). Mavzu ro'yxati esa bola sinfini qoplagan mavzularni qaytaradi.
7. **Boshqa fan.** `subject` va mavzu fani mos kelmasa → `422 TOPIC_NOT_AVAILABLE`. Profil fanlari ichida bo'lmagan
   fan bo'yicha ham mavzu boshlash mumkin (mavjud qoida: u amaliyot, DON yo'q).
8. **Import `topicId`si** (shartnomada yo'q, kichik qo'shimcha): kontent jamoasi mavzu uchun savollarni
   to'g'ridan-to'g'ri import qilishi uchun. `existing: 'skip'` mavjud savollarga tegmaydi.
9. **Savol tanlash `LearningPickService`ga ajratildi** (`learning.service.ts` hajmi uchun); oddiy urinish mantig'i
   o'zgarmagan (mavjud e2e testlar o'zgarishsiz o'tadi).

## 7. Backfill skripti

`backend/scripts/learning/backfill-topics.ts` — idempotent, DRY-RUN standart:

```bash
cd backend
npx tsx scripts/learning/backfill-topics.ts            # hisobot, bazaga yozilmaydi
npx tsx scripts/learning/backfill-topics.ts --apply    # yozadi (bitta tranzaksiya)
# serverda: cd ~/new-platform/backend && ./node_modules/.bin/tsx scripts/learning/backfill-topics.ts [--apply]
```

Har fan uchun `topic_id IS NULL` savollar normallashtirilgan `topic.uz` (NFC, bo'shliqlar, kichik harf) bo'yicha
guruhlanadi. Shu fanda shu nomli mavzu bor bo'lsa qayta ishlatiladi (o'zgartirilmaydi); yo'q bo'lsa yaratiladi:
kalit = sarlavhadan slug (kirill → lotin, `oʻ`/`gʻ` apostroflari tushiriladi, to'qnashsa `-2`, `-3`), `title` =
birinchi savolning topic JSON'i, `minGrade/maxGrade` = savollarning min/maxi, `position` = `(minGrade, title.uz)`
tartibi (mavjud mavzulardan keyin). Keyin savollar bog'lanadi. Eski `topic` ustuni tegilmaydi.
Hisobot: yaratilgan/qayta ishlatilgan mavzular, bog'langan savollar, yaroqsiz topic JSON (o'tkazib yuboriladi) va
10 tadan kam faol savolli mavzular.

Mahalliy tekshiruv (toza bazada barcha migratsiyalar + 330 ta bank savoli): 273 ta mavzu, 330 savol, 273 tasi
10 tadan kam savolli (har fan: biology 23, chemistry 25, english 38, geography 22, history 23, informatics 20,
math 38, native 31, physics 25, russian 28); ikkinchi `--apply` ishga tushirishda 0/0/0.

## 8. Deploy

1. `main`ga merge → CI `prisma migrate deploy` migratsiyani qo'llaydi. U **additive**: yangi jadval, nullable
   ustunlar, indekslar, FK (`ON DELETE SET NULL`); eski ilovalar va ma'lumotlar o'zgarmaydi. Ilova kodi migratsiyadan
   keyin ishga tushadi (mavjud deploy tartibi), eski ilova versiyalari yangi maydonlarni e'tiborsiz qoldiradi.
2. **Qaror (2026-11-06): backfill prod'da `--apply` qilinmaydi.** Mavjud 330 savoldagi erkin `topic` matnidan
   273 ta mavzu chiqadi va har birida 1–2 savol bo'ladi (dry-run). Bu katalogni chalkashtirib yuboradi.
   Shuning o'rniga metodistlar admin panelning «Mavzular» sahifasida dastur mavzularini (fan, sinf, tartib)
   o'zlari yaratadi va «Mavzusiz» filtri orqali mavjud savollarni ularga biriktiradi. Skript tahlil uchun
   (dry-run) qoladi; takror ishga tushirilsa zarar yo'q.
3. Kontent jamoasi admin panelda mavzularni tartiblaydi/nomlaydi va har mavzuga 10–20+ savol yuklaydi
   (`POST /admin/learning/topics/:id/questions` yoki import `topicId`). 10 ta faol savol (bola sinfi uchun)
   to'lguncha mavzu `available: false` — ilova aralash kunlik mashqda qoladi.
4. Orqaga qaytarish: yangi endpointlarni ishlatmaslik yetarli; ustun/jadvallarni olib tashlash shart emas.

## 9. Testlar

- Unit: `topic-mastery.spec.ts`, `topic-input.spec.ts`, `topic-backfill.spec.ts`.
- E2E (haqiqiy Postgres, `npm run test:db:up`, `npm run test:e2e` — `--runInBand`):
  `learning-topics.e2e-spec.ts` (bola API: huquqlar, daraja/dalil chegaralari, `currentTopicId`, 422, davom ettirish,
  oddiy urinish eskicha), `admin-learning-topics.e2e-spec.ts` (CRUD, validatsiya, 409, reorder mismatch,
  bog'lash, savol `topicId`, audit), `learning-topics-backfill.e2e-spec.ts` (dry-run/apply/idempotentlik).

## 10. Ochiq savollar

- Admin savol yaratishda eski `topic` JSON hali majburiy (mavzu sarlavhasi takrorlanadi). `topicId` berilsa uni
  mavzu sarlavhasidan avtomatik to'ldirish mumkin — keyingi kichik qadam.
- `lastAssessedAt` ni faqat mavzu urinishlaridan hisoblash kerakmi (hozir har qanday yakunlangan urinishdagi dalildan).
