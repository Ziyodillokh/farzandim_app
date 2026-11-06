# Bola ovozi (H01–H10) — backend kontrakti

Branch: `feat/child-voice-api` (origin/main `5bf570ee`'dan). Migratsiya: **`20261107090000_child_voice`**
(faqat qo'shuvchi: 4 yangi jadval — `school_care_participation`, `school_care_anon_responses`,
`school_care_messages`, `school_care_settings`; `school_care_requests`ga 9 ta nullable ustun;
`school_psych_assignments`ga `student_ids` (default `[]`) va `care_request_id`;
`school_staff_notifications`ga `staff_ids` (default `[]`)). Mavjud qatorlarga tegilmaydi.

Parvoz Growth bola ilovasining "Bola ovozi" bo'limi (3-faza): **A** haqiqiy anonim so'rovnoma, **B** bola ↔ psixolog
yozishmasi, **C** mas'ul psixolog / ish vaqti / muddat sozlamalari va eskalatsiya, **D** mutaxassis tayinlagan
shaxsiy test, **E** bildirishnomalar, **F** ma'lumotlarni o'chirish. Hamma yo'l `/api` prefiksi bilan.

## 0. Umumiy qoidalar

- **Bola yo'llari** (`/api/child/school/care/...`): `Authorization: Bearer <consumer JWT>`, rol `CHILD`.
  Ota-ona tokeni → `403`, tokensiz → `401`.
- **Bola maktabga bog'lanmagan** (o'quvchi yo'q / arxivlangan / sinfsiz / maktab nofaol) → `404`
  `{ "statusCode": 404, "code": "NOT_ENROLLED", "message": "Child is not linked to a school" }` — barcha YANGI bola
  yo'llarida (`contact`, `requests/:id`, `requests/:id/messages`). **Istisno (avvalgidek):** `GET survey` →
  `{ "enrolled": false, "survey": null, "answered": false }`, `GET requests` → `[]`, `POST requests` → `NOT_ENROLLED`.
- **Xatolar:** xodim yo'llari `{ statusCode, code, message }`, `code` ∈ `VALIDATION | NOT_FOUND | FORBIDDEN | CONFLICT`;
  `VALIDATION.message` = `"maydon.yo'li: errors.form.<kalit>"`. Bola yo'llari o'z kodlari bilan (quyida).
- **Sana/vaqt:** `...At` — ISO-8601 (UTC); soat `HH:MM` — Toshkent; kun hisobi — Toshkent.
- **Tenant izolyatsiyasi:** xodim faqat o'z maktabi (boshqa maktab → `404`); bola faqat o'zining murojaatlari
  (boshqa bolaning id'si → `404 REQUEST_NOT_FOUND`).
- **Cheklovlar:** kuniga 5 murojaat (takror `clientRequestId` hisoblanmaydi) → `429 TOO_MANY_REQUESTS`;
  kuniga 30 bola xabari (boshlang'ich xabarlar ham hisobda; takror `clientMessageId` hisoblanmaydi) → `429`.
- Matnlar (javoblar, murojaat, xabarlar, eslatmalar) bazada `SCHOOL_DATA_KEY` bilan AES-256-GCM shifrlangan.
  Audit yozuvlarida, saqlangan bildirishnomalarda, pushda va logda **bola ismi, matn yoki o'quvchi id'si yo'q**.

## A. Haqiqiy anonim so'rovnoma

Avval `SchoolCareResponse` o'quvchi id'sini saqlardi (anonim emas). Endi (eski jadval o'zgarmaydi va o'qishda hamon hisobga olinadi):

| Jadval | Ustunlar | Vazifa |
|---|---|---|
| `school_care_participation` | `id, survey_id, student_id, created_at`; `UNIQUE(survey_id, student_id)` | faqat "bu bola javob berdi" (javobsiz) |
| `school_care_anon_responses` | `id` (tasodifiy UUID), `survey_id, school_id, class_id?, grade, age_group, answers_enc` | shifrlangan javob — **o'quvchi / bola ustuni ham, vaqt ustuni ham yo'q** |

Ikkala qator **bitta tranzaksiyada** yoziladi (biri yozilmasa ikkinchisi ham qolmaydi), lekin ularni bog'laydigan ustun
(umumiy id, vaqt belgisi) yo'q. Anonim qatorlar o'qilganda tasodifiy `id` bo'yicha tartiblanadi (kiritilish tartibi
chiqmaydi). Umumlashtirish (`CareStore.responses()`, respondentlar soni, hisobotlar) eski va anonim qatorlarni bir xil o'qiydi;
K=5 yashirish va "faol so'rovnomada direktor faqat ishtirokni ko'radi" qoidalari o'zgarmagan.

### `GET /api/child/school/care/survey`

```json
{ "enrolled": true, "answered": false,
  "survey": { "id": "…", "title": "…", "activatedAt": "2026-11-01T04:00:00.000Z",
              "questionCount": 8, "estimatedMinutes": 2,
              "questions": [{ "id": "…", "text": "…" }] } }
```
`answered` = ishtirok belgisi YOKI eski javob qatori bor (bunda `survey: null`). `estimatedMinutes = max(1, ceil(questionCount * 15 / 60))`.
Savollar bolaning yosh guruhiga mos, faol va bola tilida.

### `POST /api/child/school/care/survey/:surveyId/responses` → `201 { "ok": true }`

Body `{ "answers": { "<questionId>": 1..5 } }`. O'tkazib yuborilgan savol umuman yuborilmaydi (hech qachon `0` bo'lib saqlanmaydi).
Kamida 1 ta javob (aks holda `400 VALIDATION` `answers: errors.form.selectAtLeastOne`); so'rovnomada yo'q / nofaol / yosh guruhiga
mos kelmaydigan savol id'si → `400` `answers: errors.form.invalid`; qiymat 1..5 butun son bo'lishi shart; faol bo'lmagan yoki
boshqa maktab so'rovnomasi → `404 SURVEY_NOT_FOUND`; ikkinchi marta → `409 ALREADY_ANSWERED` (parallel so'rovlarda ham bitta qator).
So'rovnoma holati tranzaksiya ichida `FOR SHARE` bilan qayta tekshiriladi: yopish bilan poygada javob yopilgan so'rovnomaga tushmaydi (`404`).

### Anonimlik kafolati va chegarasi

- **Kafolat (API / dastur darajasi):** hech bir API javobi, log, audit yoki bildirishnoma anonim javobni o'quvchiga bog'lamaydi;
  anonim qatorda o'quvchi / bola id'si va vaqt ustuni yo'q; ikki bolaning javobi K=5 dan kichik guruhda ko'rinmaydi.
- **Chegara:** bitta tranzaksiyada yozilgani uchun bazaga to'g'ridan-to'g'ri (SQL) kirgan superuser PostgreSQL tizim ustunlari
  (`xmin`, `ctid` — yozilish tartibi) orqali ikki qatorni taqqoslay olishi mumkin. Bu "ishtirok va javob bitta tranzaksiyada"
  talabining tabiiy natijasi; ishlab chiqarish bazasiga SQL kirish cheklangan bo'lishi shart (deploy eslatmalariga qarang).

## B. Murojaat yozishmasi (bola ↔ psixolog)

`SchoolCareRequest`ga ustunlar: `clientRequestId` (`UNIQUE(studentId, clientRequestId)`), `childId` (murojaatni yozgan bola profili; eski qatorlarda `null`), `assignedStaffId`, `openedAt`,
`openedByStaffId`, `repliedAt`, `resolvedAt`, `escalatedAt`, `lastMessageAt`. Yangi `SchoolCareMessage`
(`requestId` cascade, `author` `CHILD|STAFF`, `staffId?`, `bodyEnc`, `clientMessageId?`, `createdAt`, `readByChildAt?`, `readByStaffAt?`,
`UNIQUE(requestId, clientMessageId)`). Murojaat yaratilganda birinchi `CHILD` xabari ham yoziladi. Eski (xabarsiz) murojaat uchun
yozishma `messageEnc`dan id `"initial"` bo'lgan sintetik xabar bilan tuziladi (haqiqiy xabarlar qo'shilgandan keyin ham asl matn boshida qoladi).

**Bosqich (`stage`):** `RECEIVED` (hali ochilmagan) → `OPENED` (ochilgan, xodim xabari yo'q) → `REPLIED` (≥1 xodim xabari) →
`CLOSED` (`status = RESOLVED`). Xodim holatini (`NEW` dan boshqaga) o'zgartirgan eski murojaat `openedAt`siz ham `OPENED` hisoblanadi.
**`handler`:** `escalatedAt` bor va o'rinbosar faol bo'lsa — o'rinbosar (`isDeputy: true`); aks holda mas'ul psixolog (`isDeputy: false`); aks holda `null`.
Ichki eslatmalar (`notesEnc`) bolaga HECH QACHON qaytmaydi.
**Egalik:** bola murojaatni o'quvchi yozuvi VA `childId` (yozgan bola profili) bo'yicha ko'radi. O'quvchi yozuvi boshqa bola profiliga (masalan aka-uka) qayta bog'lansa,
avvalgi yozishma yangisiga ko'rinmaydi (`404`), xodim javobining push'i ham asl bolaga ketadi; eski qatorlarda (`childId = null`) faqat o'quvchi yozuvi tekshiriladi.

### Bola

`POST /api/child/school/care/requests` → `201` (murojaat tafsiloti, quyida). Body:
```json
{ "message": "1..1000", "urgency": "NORMAL|URGENT (default NORMAL)", "topic": "LEARNING|PEERS|BULLYING|FAMILY|EMOTIONS|SAFETY|OTHER (default OTHER)", "clientRequestId": "<uuid, ixtiyoriy>" }
```
Bir xil `(bola, clientRequestId)` — mavjud murojaat (dublikat ham, kunlik limit hisobi ham yo'q; limitga yetgan bo'lsa ham). Kuniga 5 → `429`.
`assignedStaffId` = sozlangan mas'ul psixolog (bo'lsa). `URGENT` bo'lsa mas'ul psixolog va o'rinbosarga saqlangan bildirishnoma (E).

`GET /api/child/school/care/requests` — massiv, matnsiz (eng yangisi birinchi, ≤ 20):
```json
[{ "id": "…", "topic": "OTHER", "urgency": "URGENT", "status": "NEW", "stage": "RECEIVED",
   "createdAt": "…", "meetingAt": null, "lastMessageAt": "…", "unread": 0 }]
```
`unread` = `readByChildAt = null` bo'lgan `STAFF` xabarlari soni; `lastMessageAt` yo'q bo'lsa `createdAt`.

`GET /api/child/school/care/requests/:id` — tafsilot; `STAFF` xabarlari `readByChildAt = hozir` bilan belgilanadi:
```json
{ "id": "…", "urgency": "URGENT", "status": "IN_PROGRESS", "stage": "REPLIED",
  "createdAt": "…", "openedAt": "…", "repliedAt": "…", "resolvedAt": null, "meetingAt": null,
  "handler": { "name": "Dilnoza opa", "isDeputy": false },
  "messages": [
    { "id": "…", "author": "CHILD", "authorName": null, "text": "…", "createdAt": "…" },
    { "id": "…", "author": "STAFF", "authorName": "Dilnoza opa", "text": "…", "createdAt": "…" } ] }
```
Xodim xabarining `authorName` — sozlangan ko'rsatiladigan ism (mas'ul psixolog / o'rinbosar), bo'lmasa xodim F.I.Sh.
Noto'g'ri UUID → `400`; boshqa bolaning id'si → `404 REQUEST_NOT_FOUND`.

`POST /api/child/school/care/requests/:id/messages` — body `{ "text": "1..1000", "clientMessageId": "<uuid, ixtiyoriy>" }` → `201`
`{ "id", "author": "CHILD", "authorName": null, "text", "createdAt" }`. Takror `clientMessageId` — o'sha xabar (`201`). Yopilgan (`RESOLVED`)
murojaat → `409 { "code": "REQUEST_CLOSED" }`. Kuniga 30 ta → `429 TOO_MANY_REQUESTS`. Murojaat qatori qulflanadi, shuning uchun
psixolog "hal qildi" qilayotganda xabar o'tib ketmaydi.

### Xodim (`care.individual`: faqat psixolog)

- `GET /api/school/care/requests` — qatorlarga qo'shildi: `openedAt`, `repliedAt`, `unreadFromChild`, `assignedTo {id,name}|null`, `escalatedAt`
  (`unreadFromChild` = `readByStaffAt = null` bo'lgan `CHILD` xabarlari; eski murojaatda 0).
- `GET /api/school/care/requests/:id` — tafsilot. **Birinchi ko'rgan** xodim `openedAt` / `openedByStaffId`ni yozadi (audit `care.request.open`,
  matnsiz, `entityId` yo'q). Faqat bir marta va poygaga chidamli: shartli `UPDATE ... WHERE opened_at IS NULL` — parallel ko'rishlarda
  faqat bittasi yozadi va audit qiladi. `care.individual`siz xodim (direktor, sinf rahbari) `403` oladi va hech narsa yozilmaydi.
  Javobga qo'shildi: `messages` (bola shaklidagi, lekin xodim xabarida `authorName` = xodim F.I.Sh.), `openedBy {id,name}|null`,
  `resolvedAt`, `escalatedAt`, `assignedTo`. Bolaning xabarlari `readByStaffAt` bilan belgilanadi.
- `POST /api/school/care/requests/:id/messages` — body `{ "text": "1..2000" }` → `201` `{ id, author: "STAFF", authorName, text, createdAt }`.
  Birinchi javob `repliedAt`ni, har javob `lastMessageAt`ni yozadi; `NEW → IN_PROGRESS`; `RESOLVED` → `409 CONFLICT` (`message: "REQUEST_CLOSED"`).
  Audit `care.request.reply` (matnsiz). Bolaga neytral push (E) — tranzaksiyadan KEYIN, xatosi javobni yiqitmaydi.
- `PUT /api/school/care/requests/:id/status` — `RESOLVED` `resolvedAt`ni birinchi marta yozadi (qayta bosilsa o'zgarmaydi); qayta ochilsa tozalanadi.
- Ichki eslatma, suhbat vaqti, himoya protokoli — o'zgarmagan. Eslatma / holat / suhbat vaqti / protokol ham (ko'rmasdan tegilgan murojaat uchun)
  birinchi ochish sifatida yoziladi (xuddi shu qoida: bir marta, birinchi xodim).

## C. Sozlamalar: mas'ul psixolog, o'rinbosar, ish vaqti, muddat

`SchoolCareSettings` (maktabga bitta qator): `psychologistStaffId?`, `psychologistDisplayName?`, `deputyStaffId?`, `deputyDisplayName?`,
`workDays` (default `[1,2,3,4,5]`, ISO: 1 = dushanba … 7 = yakshanba), `workStart` (`09:00`), `workEnd` (`17:00`),
`urgentSlaMinutes` (60), `normalSlaHours` (24), `updatedAt`, `updatedByStaffId?`.

- `GET /api/school/care/settings` (`care.aggregate` YOKI `care.individual` YOKI `care.settings`: direktor, administrator, psixolog) — sozlamalar (qator yo'q bo'lsa standart
  qiymatlar, `updatedAt: null`) + `staffOptions: [{ "id", "fullName" }]` (shu maktabning faol PSYCHOLOGIST xodimlari):
  ```json
  { "psychologistStaffId": null, "psychologistDisplayName": null, "deputyStaffId": null, "deputyDisplayName": null,
    "workDays": [1,2,3,4,5], "workStart": "09:00", "workEnd": "17:00", "urgentSlaMinutes": 60, "normalSlaHours": 24,
    "updatedAt": null, "updatedByStaffId": null, "staffOptions": [{ "id": "…", "fullName": "…" }] }
  ```
- `PUT /api/school/care/settings` (FAQAT `care.settings` — YANGI ruxsat: direktor, administrator, psixolog; sinf rahbari / o'qituvchi / navbatchi → `403`) — to'liq almashtirish (berilmagan maydon → standart / `null`); javob GET bilan bir xil.
  Tekshiruv (`400 VALIDATION`, `maydon: errors.form.<kalit>`): xodim shu maktabda, faol va `PSYCHOLOGIST` (`psychologistStaffId|deputyStaffId: invalidStaff`);
  o'rinbosar ≠ psixolog (`deputyStaffId: duplicate`); ko'rsatiladigan ism ≤ 40 (`tooLong`); `workStart < workEnd` (`workEnd: endBeforeStart`;
  format `invalidTime`); `workDays` 1..7, takrorsiz, kamida bitta (`outOfRange` / `duplicate` / `selectAtLeastOne`); `urgentSlaMinutes` 15..1440, `normalSlaHours` 1..168 (`outOfRange`).
  Audit `care.settings.update` (ism / id'siz).

### `GET /api/child/school/care/contact`
```json
{ "psychologist": { "name": "Dilnoza opa" }, "deputy": { "name": "Kamola opa" },
  "hours": { "days": [1,2,3,4,5], "start": "09:00", "end": "17:00" },
  "openNow": false, "nextOpenAt": "2026-11-09T04:00:00.000Z" }
```
`name` = ko'rsatiladigan ism, bo'lmasa xodim F.I.Sh.; faol bo'lmagan xodim ko'rsatilmaydi. Psixolog o'rnatilmagan va ko'rsatiladigan ism ham yo'q bo'lsa — maktabdagi
YAGONA faol psixolog (bir nechta bo'lsa `null`). Sozlama qatori yo'q: `hours: null`, `openNow: false`, `nextOpenAt: null`. Bayramlar (`SchoolHoliday`) yopiq hisoblanadi.
Hozir ochiq bo'lsa `nextOpenAt: null`; yopiq bo'lsa — keyingi ish oynasining boshi.

### Eskalatsiya (cron, har 5 daqiqada, Toshkent — `@nestjs/schedule`, `care-escalation.cron.ts`)

Shart: `status = NEW`, `openedAt = null`, `escalatedAt = null`, muddat o'tgan va maktabda **faol PSYCHOLOGIST o'rinbosar** sozlangan. Muddat — `createdAt`dan
boshlab **ish vaqtida**: `URGENT` = `urgentSlaMinutes`, `NORMAL` = `normalSlaHours * 60` daqiqa. Ish vaqti: `workDays` kunlarida `[workStart, workEnd)`, bayramlar yopiq,
yaratilgan payt ish vaqtidan tashqarida bo'lsa hisob keyingi ish oynasi boshidan boshlanadi (sof funksiya `care-working-time.ts`: `addWorkingMinutes`, `nextWorkingStart`, `isWorkingAt`).
Natija: `assignedStaffId = o'rinbosar`, `escalatedAt = hozir`; o'rinbosarga nishonlangan saqlangan bildirishnoma; `URGENT` bo'lsa direktorga ismsiz xavfsizlik signali;
audit `care.request.escalate` (tizim, matnsiz). Shartli `UPDATE` — parallel nusxalarda ham bir murojaat ikki marta o'tmaydi. Bola `handler`da o'rinbosarni ko'radi.

## D. Mutaxassis tayinlagan shaxsiy test (H10)

`POST /api/school/assessments/assignments` (`assessments.manage`) — maqsadga qo'shildi:
```json
{ "testId": "…", "target": { "kind": "STUDENTS", "studentIds": ["<studentId>"] },
  "careRequestId": "<ixtiyoriy>", "opensAt": "2026-11-06T09:00", "closesAt": "2026-11-13T09:00", "consent": true }
```
`studentIds`: 1..30 (takrorlar birlashtiriladi), hammasi shu maktabning, xodim doirasida, arxivlanmagan va test sinf darajasiga mos bo'lishi shart — aks holda
`400 target.studentIds: assessments.validation.noStudents` (begona / noma'lum id farqlanmaydi). `consent: true` avvalgidek majburiy. `careRequestId` shu maktab murojaati
bo'lishi shart (`careRequestId: errors.form.invalid`); `target` ichida ham qabul qilinadi, lekin saqlanadigan `target`ga kirmaydi. Parvoz IQ ham shaxsiy tayinlanadi.
Qator: `classIds: []`, `studentIds`, `careRequestId`, `invited = studentIds.length`; ro'yxat va natijalarda taklif qilinganlar / yakunlaganlar shu o'quvchilar bo'yicha.
**Natijalar maxfiyligi:** shaxsiy tayinlash natijalari faqat psixologga (`assessments.manage`) testlar bo'limida ko'rinadi; sinf rahbariga (`GET /tests/:id/results`, `taklif qilinganlar` ham 0)
va rivojlanish indeksiga / profillariga (`AssessmentsStore.scoredResults`) kirmaydi.

Bola ko'rinishi: `classIds has student.classId` YOKI `studentIds has student.id`. `GET /api/child/school/assessments` qatorlariga qo'shildi (mavjud maydonlar saqlangan):
```json
{ "assignmentId": "…", "testId": "…", "kind": "CUSTOM", "title": "…", "description": "…", "itemCount": 4, "timeLimitMin": 10, "closesAt": "…",
  "personal": true, "assignedBy": { "name": "Dilnoza opa" }, "questionCount": 4, "estimatedMinutes": 1 }
```
`personal` — `STUDENTS` maqsadi; `assignedBy.name` — yaratuvchi sozlangan mas'ul psixolog / o'rinbosar bo'lsa uning ko'rsatiladigan ismi, aks holda F.I.Sh. (xodim topilmasa `null`);
`estimatedMinutes` so'rovnoma bilan bir xil formula.

## E. Bildirishnomalar

- **Xodim reply → bolaga FCM** (bolaning qurilma tokeni bo'lsa): `data { "type": "CARE_MESSAGE", "requestId": "…" }`, matn NEYTRAL — uz "Sizga yangi xabar keldi",
  ru "Вам новое сообщение" (sarlavha "Parvoz"); mazmun ham, "psixolog" so'zi ham yo'q. Token yo'q → jim o'tkazib yuboriladi (faqat log, id'siz); FCM xatosi javobni yiqitmaydi.
- **`URGENT` murojaat yaratilsa:** sozlangan mas'ul psixolog va o'rinbosarga saqlangan bildirishnoma (`CARE_URGENT`, id `care:<requestId>`, faqat sinf nomi va mavzu yorlig'i).
  Hisoblangan lentadagi bir xil id'li yozuv bilan birlashtiriladi (nishonlangan xodimda bittadan ko'rinadi). Murojaat `NEW`dan chiqqach (javob / holat) saqlangan yozuvlar tozalanadi.
- **Eskalatsiya:** o'rinbosarga (`CARE_URGENT` yoki `CARE_NEW`, id `care-esc:<requestId>`, izoh "Muddatida ochilmadi — sizga o'tkazildi"); `URGENT` bo'lsa direktorga
  `SAFETY_SIGNAL` (id `care-esc-dir:<murojaat id'sining sha256 xeshi>`, ism / sinf / havolasiz — direktorga murojaat id'si ochilmaydi). `SchoolStaffNotification.staffIds` (bo'sh — rolga mos hammaga) nishonlash uchun.
- So'rovnoma va murojaat uchun DON / ball yo'q.

## F. Ma'lumotlarni o'chirish

To'rt yo'lda ham (bola o'z akkauntini o'chirsa — `ChildDataPurgeService.deleteChildAccount`; ota-ona bola profilini o'chirsa — `purgeChildProfile`; ota-ona o'z akkauntini —
`UsersService.deleteAccount`; admin foydalanuvchini — `AdminUsersService.deleteUser`) shu bolaga bog'langan o'quvchining **murojaatlari (xabarlar cascade)**, ularga bog'liq
saqlangan xodim bildirishnomalari va **so'rovnoma ishtirok belgilari** o'chadi; o'quvchi qatori qoladi. O'chirish child o'chirilishidan OLDIN bajariladi (`childId` bog'lanishi `SetNull` bo'ladi).
Shaxsiy test tayinlashidagi shu murojaatga havola (`careRequestId`) `null` qilinadi (tayinlashning o'zi qoladi). Qulf tartibi javob / eskalatsiya bilan bir xil (avval murojaat, keyin bildirishnomalar).
Yordamchi: `school/care/care-purge.ts` (`deleteCareOfChildren`).

**Anonim javoblar O'CHIRILMAYDI** — ular o'quvchiga bog'lanmagan (shunday loyihalangan), kimniki ekanini aniqlab bo'lmaydi. Eski `school_care_responses` qatorlari ham tegilmaydi
(maktab yozuvi; o'quvchi qatori ham o'chmaydi) — "bugungi holat" bilan mos.

## Qarorlar va og'ishlar

1. **`POST …/survey/:id/responses` → `201`** (kontraktda `200`). Mavjud yo'l 201 qaytaradi va eski ilova versiyalari shunga tayanishi mumkin; yangi mijoz 200 va 201 ni ikkalasini muvaffaqiyat deb qabul qilsin.
2. **`contact.nextOpenAt`** hozir ochiq bo'lsa `null` (kontrakt namunasida `openNow: true` bilan sana berilgan — namuna deb qabul qilindi); yopiq bo'lsa keyingi ish oynasi boshi.
3. **`handler` va `contact`** bir xil qoida bilan mas'ul shaxsni aniqlaydi (sozlama yo'q / psixolog o'rnatilmagan — yagona faol psixolog); `assignedStaffId` esa faqat AYNAN sozlangan psixologdan olinadi.
4. **`POST requests` takrori ham `201`** (yangi va mavjud murojaat uchun bir xil status, bir xil tana).
5. **`SchoolCareAnonResponse.grade` majburiy** (kontraktda `grade?`): javob paytida sinf doim ma'lum; `classId` nullable (eski jadval kabi, sinfsiz qator hisobga kirmaydi).
6. **Yangi ruxsat `care.settings`** (mahsulot egasi qarori: administrator ham sozlamalarni tahrirlay olsin): DIRECTOR, ADMIN, PSYCHOLOGIST'ga beriladi (butun maktab). `PUT /school/care/settings` uchun YAGONA ruxsat; `GET` — `care.aggregate` YOKI `care.individual` YOKI `care.settings`.
   `backend/src/school/auth/permissions.ts` va `school-panel/src/auth/permissions.ts` matritsalari bir xil (backend unit testi ikkalasini taqqoslaydi). `care.settings` himoyalangan rollar (`PROTECTED_ROLES`) ro'yxatiga ta'sir qilmaydi — administrator / direktor bolalar murojaati mazmunini ko'rmaydi.
7. **Saqlangan bildirishnoma nishonlash:** `SchoolStaffNotification` faqat rolga mos edi, shuning uchun qo'shuvchi `staff_ids` ustuni qo'shildi. Yangi `kind` kiritilmadi (panel noma'lum kindda yiqilmasin): mavjud `CARE_URGENT` / `CARE_NEW` / `SAFETY_SIGNAL` ishlatiladi, farq `subject` matnida.
8. **`ResponseRow.studentId` → `respondentId`** (`care-aggregate`): anonim qatorlarda o'quvchi id'si yo'q; eski qatorlarda o'quvchi id'si, anonimda qator id'si — faqat "necha KISHI" hisoblash uchun. `care-aggregate.spec.ts` fixture maydon nomi shunga moslandi (assertlar o'zgarmadi).
9. **`EnrolledStudent` (`school/common/child-student.ts`)** ga `grade` va `lang` qo'shildi (qo'shimcha maydon, mavjud iste'molchilar o'zgarmadi).
10. **Birinchi ochish** faqat `GET` bilan emas, ko'rmasdan tegilgan murojaat uchun (eslatma, holat, suhbat vaqti, protokol, javob) ham yoziladi — bir xil qoida (bir marta, birinchi xodim).
11. **Yopiq murojaatga xodim javobi:** `409 CONFLICT` (`message: "REQUEST_CLOSED"`) — xodim xatolari `code` to'plamiga mos; bola tomonida `code: "REQUEST_CLOSED"`.
12. **Bola xabarlari limiti (30/kun)** boshlang'ich xabarlarni ham hisoblaydi (ular ham `CHILD` xabari).
13. **Shaxsiy test:** `careRequestId` so'rov tanasida (kanonik), `target` ichida ham qabul qilinadi; o'quvchi sinfi test darajasiga mos bo'lishi shart; sinf bo'yicha tayinlashdagi `classNames` shaxsiy tayinlashda bo'sh.
14. **Shaxsiy test natijalari** sinf rahbari va rivojlanish ko'rinishlaridan YASHIRILGAN (mutaxassis tanlagan bola ajralib qolmasin); psixolog uchun rivojlanish profilida ham ular yo'q — faqat testlar natijalari sahifasida (mahsulot egasi tasdiqlasin).
15. **Eskalatsiya o'rinbosari** faol `PSYCHOLOGIST` bo'lishi shart; o'rinbosar faol bo'lmasa cron murojaatni o'tkazmaydi (qayta urinadi). Ochilgandan keyin yoki bola yangi xabar yozganda qayta eskalatsiya yo'q.
16. **Ishtirok belgisi o'chirilgach** (F bo'limi) o'quvchiga yangi bola akkaunti ulansa, u FAOL so'rovnomaga yana javob bera oladi — anonim javob o'chirilmagani uchun shu so'rovnomada bir o'quvchidan ikkita javob bo'lishi mumkin (kichik chekka holat; mahsulot egasi savoli).
17. **Faol so'rovnomada psixolog jonli natijani ko'radi** (mavjud qaror o'zgarmadi): yangi javoblar sonining o'zgarishini murojaat vaqti bilan solishtirib, bitta bolaning javobini taxmin qilish mumkin. Faqat YOPILGANdan keyin ko'rsatish yoki yangilanishni to'plab berish tavsiya etiladi (mahsulot egasi savoli).
18. **Bola xabari uchun xodimga alohida bildirishnoma yo'q** (hisoblangan lenta faqat `NEW` murojaatlarni ko'rsatadi; panel `unreadFromChild`dan foydalanadi) — mahsulot egasi savoli.

## Panel uchun yangi i18n kalitlari

- `errors.form.invalidStaff` (xodim topilmadi / faol emas / psixolog emas), `errors.form.duplicate`, `errors.form.outOfRange`, `errors.form.invalid` (mavjud: `required`, `tooLong`, `invalidTime`, `endBeforeStart`, `selectAtLeastOne`).
- `assessments.validation.noStudents` (shaxsiy tayinlash: o'quvchilar topilmadi / mos emas).
- Audit amallari: `care.request.open`, `care.request.reply`, `care.request.escalate`, `care.settings.update` (`audit.actions.<action>`).
- Yangi ruxsat `care.settings` — panel `school-panel/src/auth/permissions.ts` (`PERMISSIONS` va DIRECTOR / ADMIN / PSYCHOLOGIST) shu loyihada sinxronlandi; panel menyu / route-manifest va sozlamalar sahifasi hali yo'q (boshqa agent).

## Deploy eslatmalari

- `main`ga merge = prod deploy (+ `prisma migrate deploy`). Migratsiya faqat qo'shuvchi; orqaga qaytarish: yangi jadvallarni `DROP` va qo'shilgan ustunlarni olib tashlash (eski kod ularni ishlatmaydi).
  Eski ilova / panel versiyalari ishlashda davom etadi: bola `POST requests` eski tanasi (`topic`, `message`, `urgency`) qabul qilinadi, ro'yxatlar faqat qo'shimcha maydon oladi.
- Yangi env yo'q. Cron `ScheduleModule` orqali o'zi ishga tushadi; **maktabda o'rinbosar sozlanmaguncha eskalatsiya ishlamaydi** (xavfsiz default). Bola push uchun `FIREBASE_SERVICE_ACCOUNT_BASE64` avvalgidek.
- **Anonimlik (operatsion):** ishlab chiqarish bazasiga to'g'ridan-to'g'ri SQL kirish cheklangan bo'lsin (A bo'limidagi chegara). Ixtiyoriy kuchaytirish: so'rovnoma yopilgach `CLUSTER school_care_anon_responses USING school_care_anon_responses_pkey`
  (tasodifiy id bo'yicha qayta tartiblaydi, kiritilish tartibini yo'qotadi). `xmin` bu bilan o'chmaydi.
- Flutter: `POST …/responses` javobi 201; yangi yo'llar `NOT_ENROLLED` kodini tanishi kerak; push `data.type = CARE_MESSAGE` bilan yozishmani ochadi.

## Testlar

Unit (`npx jest`): `care-working-time` (dam olish / bayram / ish vaqtidan tashqari), `care-anon` (anonim qator shakli Prisma DMMF orqali + yozish yo'li: bitta tranzaksiya, o'quvchi / vaqt belgisi yo'q),
`care-thread`, `care-settings` (contact, sxema), `care-notify.service` (neytral push, token yo'q, FCM xatosi), `assessments-students-target`, `child-data-purge` (murojaat / ishtirok o'chirish va tartib).
E2E (haqiqiy Postgres, `E2E_DATABASE_URL=…/<nom>_test`): `school-care-anon` (ikki bolaning javobini hech bir API ajratmaydi, atomiklik, eski + yangi qatorlar), `school-care-thread` (idempotentlik, limitlar, bosqichlar,
birinchi ochgan poygasi, push, izolyatsiya), `school-care-settings` (sozlamalar, contact, eskalatsiya cron, bildirishnomalar), `school-care-personal` (STUDENTS tayinlash), `school-care-deletion` (to'rt o'chirish yo'li);
mavjud `school-care` va `school-assessments-child` kutilmalari faqat kontrakt qo'shgan maydonlarga moslandi.
