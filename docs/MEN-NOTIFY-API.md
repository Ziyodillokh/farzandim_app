# Men (I07 + I09): bildirishnoma sozlamalari va ma'lumot o'chirish so'rovi — backend kontrakti

Branch: `feat/men-notify-api` (origin/main `512b8357`'dan). Migratsiya: **`20261108100000_men_notify`**
(FAQAT qo'shuvchi: `notification_preferences`ga 6 ta default'li ustun, 2 ta yangi jadval
`child_data_deletion_requests` va `child_push_dedupe`, 1 ta enum `ChildDeletionRequestStatus`; mavjud qatorlarga tegilmaydi,
UPDATE/DELETE yo'q). Hamma yo'l `/api` prefiksi bilan. Bu hujjat Part 2 (2A + 2B) — DON/nishon/haftalik faollik (Part 1) bu yerda yo'q.

## 0. Umumiy qoidalar

- **Kim:** "bola yoki ota-ona" = shu bolaning o'z foydalanuvchisi (`Child.childUserId`) yoki ota-onasi (`Child.parentId`) —
  gamification yo'llaridagi qoida bilan bir xil. Boshqa foydalanuvchi → `403`, mavjud bo'lmagan bola → `404`, tokensiz → `401`.
- **Vaqt:** `HH:MM` va "kun" hisobi — Toshkent (`Asia/Tashkent`, UTC+5); `...At` — ISO-8601 (UTC).
- **Xatolar:** `{ "statusCode": 400, "code": "VALIDATION", "message": "…" }` (kunlik eslatma vaqti uchun); boshqa DTO xatolari
  oddiy NestJS `400` (`message` — massiv).
- **Push hech qachon asosiy amalni yiqitmaydi.** Token yo'q bola jim o'tkazib yuboriladi. Logda xabar matni, ism, sarlavha yo'q
  (xatolar faqat turi/kodi bilan yoziladi).
- Pushlar **bolaning qurilmalariga** ketadi (ota-onaga ketadigan push'lar sozlamalarga bog'liq emas).

## 1. Bildirishnoma sozlamalari (2A)

### `GET /api/children/:childId/notification-preferences` — bola yoki ota-ona

Yozuv yo'q bo'lsa standart qiymatlar:

```json
{
  "studyNudge": true, "healthNudge": true, "contentReminder": true,
  "quietFrom": null, "quietTo": null,
  "homeworkReminder": true, "schoolAnnouncements": true, "familyMessages": true,
  "dailyReminder": true, "dailyReminderTime": "18:00", "hideText": true
}
```

### `PUT /api/children/:childId/notification-preferences` — bola yoki ota-ona (qisman)

```json
{ "hideText": false, "dailyReminderTime": "07:45", "familyMessages": false }
```

`200` — to'liq, yangilangan obyekt (GET bilan bir xil shakl). Maydonlar:

| Maydon | Turi | Ma'nosi |
|---|---|---|
| `studyNudge`, `healthNudge`, `contentReminder` | bool | Avvalgidek (ota-ona ilovasi ham shularni boshqaradi) |
| `quietFrom`, `quietTo` | `"HH:MM"` yoki `null` | Tinch soatlar (tungi oraliq ham: 22:00–08:00). Kunlik eslatma va uy vazifasi eslatmasi shu oynada yuborilmaydi |
| `homeworkReminder` | bool | Ertangi topshiriq eslatmasi (17:00) |
| `schoolAnnouncements` | bool | Maktab e'lonlari push'i (bolaga) |
| `familyMessages` | bool | Oila matn / ovoz / video / media xabarlari push'i (SOS va qo'ng'iroqlar bundan **mustasno**) |
| `dailyReminder` | bool | Kunlik o'qish eslatmasi (bola yoqadi/o'chiradi) |
| `dailyReminderTime` | `"HH:MM"` | Kunlik eslatma vaqti, **`06:00`–`21:00`** (chegaralar kiradi), aynan `HH:MM` (nol bilan: `"6:00"` emas) |
| `hideText` | bool | `true` — push lock-screen'da neytral ("Parvoz" + umumiy matn), yuboruvchi va mazmunsiz |

Xatolar:

- `dailyReminderTime` formati noto'g'ri, oraliqdan tashqarida, `null` yoki satr emas → `400`
  `{ "statusCode": 400, "code": "VALIDATION", "message": "dailyReminderTime HH:MM formatida va 06:00–21:00 oralig'ida bo'lishi kerak" }`;
  hech narsa saqlanmaydi.
- Mantiqiy maydonlarga boolean bo'lmagan yoki `null` qiymat, noma'lum maydon → `400`.
- Begona foydalanuvchi → `403`; bola topilmasa → `404`.

**Eslatma (studyNudge va dailyReminder):** kunlik o'qish eslatmasi uchun IKKALASI ham `true` bo'lishi kerak —
`studyNudge` ota-ona boshqaruvi, `dailyReminder` bolaning o'ziniki. Biri o'chiq bo'lsa eslatma yuborilmaydi.

## 2. Pushlar (bolaning qurilmalariga)

| Hodisa | Sozlama | Sarlavha / matn | `data` |
|---|---|---|---|
| Oila xabari (matn, ovoz, media, video) — qabul qiluvchi bola | `familyMessages=false` → yuborilmaydi; `hideText=true` (standart) → neytral | `Parvoz` / `Yangi xabar` (ru `Новое сообщение`, en `New message`). Yuboruvchi ham, mazmun ham yo'q | `{ type: "voice"\|"video", messageId }` (`senderId` yo'q) |
| Oila xabari, `hideText=false` | — | avvalgidek: yuboruvchi ismi / qisqa mazmun | `{ type, messageId, senderId }` |
| Kunlik o'qish eslatmasi | `studyNudge` va `dailyReminder` | avvalgi matn ("Bugun bitta test yechib ko'rchi 📚") | `{ type: "study_nudge", childId, relatedRoute }` |
| Ertangi topshiriq | `homeworkReminder` | `Parvoz` / `Ertaga topshiriq muddati` (ru `Завтра срок задания`) | `{ type: "HOMEWORK_DUE" }` |
| Maktab e'loni (`audience.includeStudents=true`) | `schoolAnnouncements`; `hideText=true` → neytral | `Parvoz` / `Maktabdan yangi eʼlon` (ru `Новое объявление школы`) | `{ type: "SCHOOL_ANNOUNCEMENT", id }` |
| Maktab e'loni, `hideText=false` | — | sarlavha: maktab nomi; matn: e'lon **sarlavhasi** (≤ 80 belgi, "…" bilan; e'lon matni emas) | `{ type: "SCHOOL_ANNOUNCEMENT", id }` |
| Psixolog javobi (`CARE_MESSAGE`) | **sozlamalarga bog'liq emas** — doim neytral | o'zgarmagan | `{ type: "CARE_MESSAGE", requestId }` |

Til — bolaning `User.language` (`uz` standart; `ru`, `en`).

### Oila xabarlari

- Sozlamalar faqat **qabul qiluvchi bola** bo'lganda amal qiladi (ota-ona → bola). Bola → ota-ona xabarlari va ota-onaga
  ketadigan push'lar avvalgidek.
- `familyMessages=false` bo'lsa ham xabar saqlanadi va bola ilovasidagi bildirishnomalar ro'yxatiga yoziladi (faqat push yo'q).
  Ro'yxatdagi yozuv ilova ichida — lock-screen'da ko'rinmaydi, shuning uchun `hideText` uni o'zgartirmaydi.
- Video xabar ham xuddi shu qoidaga bo'ysunadi (matn/ovoz bilan birga).

### Kunlik o'qish eslatmasi

- Har daqiqada tekshiriladi; bola `dailyReminderTime` (Toshkent) vaqtida, kechikib bo'lsa ham **5 daqiqagacha** yuboriladi,
  undan keyin o'sha kun uchun o'tkazib yuboriladi. Sozlamasi yo'q bola — `18:00`.
- Avvalgi mantiq: faqat bugun test yechmagan bolaga, kuniga bir marta (`lastStudyNudgeAt`), tinch soatlarda emas.
  "Bugun test yechgan" — olimpiada urinishi **yoki yakunlangan kunlik o'qish testi** (Toshkent kuni) bo'lsa.
- **Xulq o'zgarishi:** eskirgan qat'iy 16:00 eslatma olib tashlandi; endi hamma (sozlamasi borlar va yo'qlar) `18:00` da oladi
  (standart), bola vaqtni o'zgartirishi mumkin. `healthNudge` (18:00) va `contentReminder` (shanba 11:00) o'zgarmagan.

### Ertangi topshiriq eslatmasi (17:00)

- Cron: har kuni 17:00, 17:15 va 17:30 (Toshkent) — server qayta ishga tushsa o'tkazib yubormaslik uchun.
- Kim: maktabga bog'langan (faol o'quvchi, sinfi bor, maktab faol, bola ilovasi ulangan) bola, uning HOZIRGI sinfiga
  (`/child/school/assignments` ko'rinish qoidasi) berilgan topshiriq **muddati ertaga** bo'lsa va bajarilmagan bo'lsa:
  - yozma vazifa: topshirilgan (`SUBMITTED`) yoki qabul qilingan (`ACCEPTED`) bo'lsa — hisobga olinmaydi; qaytarilgan
    (`RETURNED`) yoki topshirilmagan — eslatiladi;
  - test: topshiriq berilgandan keyin shu fan bo'yicha yakunlangan urinish bo'lsa — hisobga olinmaydi;
  - bajarilganini aniqlab bo'lmaydigan material (audiokitob) — bajarilmagan hisoblanadi.
- Bola bir nechta topshiriqqa qaramay **kuniga bitta** push oladi (`child_push_dedupe`, kalit — eslatma kuni; parallel
  ishga tushirish ham dublikat bermaydi). Push matni topshiriq nomi yoki mazmunini o'z ichiga olmaydi.

### Maktab e'loni -> bolalar

- E'lon yuborilganda (darhol yoki rejalashtirilgan vaqti kelganda) va `audience.includeStudents=true` bo'lsa
  (faqat `SCHOOL` / `CLASSES`; `GUARDIANS` — hech qachon): auditoriyadagi **ilovasi ulangan** bolalarga (faol o'quvchi,
  sinfi bor, maktab faol). Boshqa sinf, arxivlangan o'quvchi, ilovasiz o'quvchi — yo'q.
- Har (e'lon, bola) uchun **bir marta** (`child_push_dedupe`, kalit — e'lon id): qayta urinish / qayta chaqirish / parallel
  ishga tushirish dublikat bermaydi. Ota-onalarga push (`announcementId` kaliti bilan) alohida va o'zgarmagan.
- Push xatosi e'lonni yuborishni yiqitmaydi.

## 3. Ma'lumotlarni o'chirish so'rovi (2B)

**Hech narsa avtomatik o'chirilmaydi** — so'rov saqlanadi va ota-ona hamda (bola maktabga bog'langan bo'lsa) maktab
rahbariyati xabardor qilinadi.

### `POST /api/children/:childId/deletion-requests` — faqat BOLA (o'zi)

So'rov tanasi yo'q. Javob (`201`):

```json
{ "id": "…", "status": "RECEIVED", "createdAt": "2026-11-08T09:12:00.000Z" }
```

- Oxirgi **30 kun** ichida `RECEIVED` so'rov bor bo'lsa → `200` va o'sha so'rov (yangi qator, push, bildirishnoma, audit **yo'q**).
  `CLOSED` yoki 30 kundan eski so'rov yangi so'rovga to'sqinlik qilmaydi. Parallel so'rovlar bola qatorini qulflash orqali
  ketma-ketlashtiriladi (bitta so'rov, bitta xabar).
- **Limit:** foydalanuvchi boshiga sutkada **3 ta** so'rov (takroriy `200` javoblar ham sanaladi) → `429`.
  Hisoblagich jarayon xotirasida (qayta ishga tushganda nollanadi; boshqa nomli throttler'lar kabi).
- Xatolar: ota-ona tokeni → `403`; boshqa bolaning id'si → `403`; bola yo'q → `404`; tokensiz → `401`.

### `GET /api/children/:childId/deletion-requests/latest` — bola yoki ota-ona

Eng so'nggi so'rov (xuddi shu shakl) yoki JSON `null` (tana — `null`, status `200`):

```json
{ "id": "…", "status": "CLOSED", "createdAt": "2026-10-01T08:00:00.000Z" }
```

`status` ∈ `RECEIVED | CLOSED`. Hozircha so'rovni yopish yo'li yo'q (xodim oqimi keyingi bosqich) — qator qo'lda yopilishi mumkin.

### Yaratilganda (best-effort, har biri alohida; xato so'rovni yiqitmaydi)

1. **Ota-onaga neytral push:** `Parvoz` / `Farzandingiz maʼlumotlarini oʻchirishni soʻradi`
   (ru `Ваш ребёнок попросил удалить свои данные`, en `Your child asked to delete their data`),
   `data: { type: "DATA_DELETION_REQUEST", childId }`. Bola ismi push'da yo'q.
2. **Maktab xodimlariga** (bola `SchoolStudent` ga bog'langan bo'lsa): saqlangan bildirishnoma
   (`SchoolStaffNotification`, id `data-deletion:<requestId>`), `kind: "DATA_DELETION_REQUEST"`, rollar `DIRECTOR` va `ADMIN`
   (butun maktab, aniq xodimlar belgilanmagan), `params: { studentName: "Familiya Ism", className: "7-A" }`, `subject` va
   `href` — `null`. Sabab, bola/so'rov id'si, boshqa ma'lumot yo'q.
3. **Audit:** `AuditLog` — `action: "CHILD_DATA_DELETION_REQUEST"`, `resourceType: "child"`, `resourceId` = so'rov id'si,
   `userId` = bola foydalanuvchisi, `data: { childId }`.

### Xodim paneli (`GET /api/school/notifications/feed`)

Yangi `kind: "DATA_DELETION_REQUEST"` (ohang `warning`) — faqat `DIRECTOR` va `ADMIN` lentasida:

```json
{ "id": "data-deletion:…", "kind": "DATA_DELETION_REQUEST", "at": "2026-11-08T09:12:00.000Z", "tone": "warning",
  "params": { "studentName": "Aliyev Vali", "className": "7-A" }, "subject": null, "href": null }
```

Panel i18n kaliti shu `kind` bo'yicha qo'shiladi (backend matn bermaydi).

### O'chirishda

Bola ma'lumotlari o'chirilganda so'rov qatorlari va ularga bog'liq xodim bildirishnomasi (o'quvchi ismi shu yerda) ham
o'chadi — hamma yo'lda: bola o'z akkauntini o'chirsa (`DELETE /users/me`, profil qoladi — shuning uchun alohida o'chiriladi),
ota-ona bola profilini o'chirsa (`DELETE /children/:id`), ota-ona akkauntini o'chirsa, admin foydalanuvchini o'chirsa.
Bola o'chganda `child_data_deletion_requests` va `child_push_dedupe` qatorlari cascade bilan ham ketadi.

## 4. Jadvallar

| Jadval | Ustunlar |
|---|---|
| `notification_preferences` (+6) | `homework_reminder`, `school_announcements`, `family_messages`, `daily_reminder` (bool, default `true`); `daily_reminder_time` (default `'18:00'`); `hide_text` (default `true`) |
| `child_data_deletion_requests` | `id`, `child_id → children (CASCADE)`, `status` (`RECEIVED` default \| `CLOSED`), `created_at`, `closed_at?`; indeks `(child_id, created_at DESC)` |
| `child_push_dedupe` | `id`, `child_id → children (CASCADE)`, `kind`, `ref_key`, `created_at`; `UNIQUE(child_id, kind, ref_key)`. `kind=HOMEWORK_DUE` (kalit: kun), `kind=SCHOOL_ANNOUNCEMENT` (kalit: e'lon id). 30 kundan eski qatorlar uy vazifasi cron'i tozalaydi |

Orqaga qaytarish: yangi jadvallar va enum'ni DROP qilish + qo'shilgan 6 ustunni olib tashlash (eski kod ularni ishlatmaydi).

## 5. Flutter ilovalari uchun eslatmalar

- Bola ilovasi push'ni `data.type` bo'yicha yo'naltiradi: `voice`/`video` (chat), `SCHOOL_ANNOUNCEMENT` (+ `id`), `HOMEWORK_DUE`,
  `study_nudge`, `CARE_MESSAGE`. Neytral push'larda sarlavha `Parvoz` — mazmunni ilova ichida ochib ko'rsating.
- Ota-ona ilovasi: `DATA_DELETION_REQUEST` + `childId` — kerakli bolaning profilini oching; holatni
  `GET …/deletion-requests/latest` bilan o'qing.
- `GET …/deletion-requests/latest` javobi mavjud bo'lmaganda **`null`** (bo'sh tana emas).
- Standart `hideText=true` — mavjud barcha bolalar uchun oila xabari push'i endi neytral (ilgari yuboruvchi ismi va matn ko'rinardi).
- Kunlik eslatma tugmasi: `dailyReminder` + `dailyReminderTime`; ota-onaning `studyNudge` o'chirgichi bilan birga amal qiladi.

## 6. Testlar

- Unit: `notification-prefs.spec.ts` (vaqt tekshiruvi, oyna, tinch soat), `family-message-push.spec.ts` (`hideText` matnlari,
  ota-onaga ta'sir qilmasligi), `nudge.service.spec.ts` (kunlik eslatma), `notification-preferences.service.spec.ts`,
  `homework-reminder.spec.ts` + `homework-reminder.service.spec.ts` (ertangi topshiriq tanlovi, submitted/accepted/done
  istisnolari, dedupe), `announcement-child-push.spec.ts` + `announcement-child-push.service.spec.ts` (auditoriya → faqat ulangan
  bolalar, dedupe), `child-push-dedupe.service.spec.ts`, `user-throttler.guard.spec.ts` (3/sutka), `error-label.spec.ts`,
  `child-data-purge.service.spec.ts` (o'chirish).
- E2E (haqiqiy Postgres): `men-notify-prefs` (23), `men-notify-schedule` (35), `men-deletion-request` (28).
- Natija: `tsc --noEmit` toza; unit — 90 suite / 996 test (shundan yangi: 11 suite, 143 test); e2e — 52 suite / 631 test, hammasi o'tadi
  (`farzandim_mennotify_test`, `prisma migrate diff --exit-code` — farq yo'q).

## 7. Ochiq savollar

1. Hozir "kunlik eslatma" `studyNudge` (ota-ona) bilan birga amal qiladi. Ota-ona o'chirgichi bolaning o'zi yoqqan
   `dailyReminder`ni bekor qilishi kerakmi, yoki `dailyReminder` yagona manba bo'lib qolsinmi?
2. Standart `hideText=true` mavjud bolalarning oila xabari push'ini neytral qiladi (kontraktga ko'ra). Ota-onalarga ma'lum qilish kerakmi?
3. So'rovni yopish (`CLOSED`) oqimi (kim, qanday, ota-onaga xabar) hali yo'q — xodim paneli bosqichi.
4. E'lon va uy vazifasi push'lari bola ilovasining bildirishnomalar ro'yxatiga (`Notification`) yozilmaydi — faqat push. Kerak bo'lsa qo'shiladi.
