# Maktab bo'limi — bola ilovasi (M01–M08) backend kontrakti

Branch: `feat/school-child-api` (origin/main'dan). Migratsiya: **`20261106130000_school_child_api`**
(faqat qo'shuvchi: yangi enum, 4 yangi jadval, `school_learning_assignments`ga 2 ta nullable ustun).

Parvoz Growth bola ilovasidagi "Maktab" bo'limi uchun to'rt blok: **A** e'lonlar, **B** davomat
tarixi, **C** dars jadvali, **D** yozma vazifa (rasm bilan topshirish). Hamma yo'l `/api` prefiksi bilan.

## 0. Umumiy qoidalar

- **Bola yo'llari** (`/api/child/school/...`): `Authorization: Bearer <consumer JWT>`, rol `CHILD`.
  Ota-ona tokeni → `403`, tokensiz → `401`.
- **Bola maktabga bog'lanmagan** (o'quvchi yo'q / arxivlangan / sinfsiz / maktab nofaol) → `404`
  `{ "statusCode": 404, "code": "NOT_ENROLLED", "message": "Child is not linked to a school" }`.
  Bu hamma YANGI yo'llarga tegishli. **Istisno:** mavjud `GET /child/school/assignments` avvalgidek
  bog'lanmagan bola uchun `[]` qaytaradi.
- **Xatolar:** maktab xatolari `{ statusCode, code, message }`, `code` ∈ `VALIDATION | NOT_FOUND | FORBIDDEN | CONFLICT`;
  `VALIDATION.message` = `"maydon.yo'li: errors.form.<kalit>"` (panel i18n kaliti).
- **Sana/vaqt:** kun — Toshkent `YYYY-MM-DD`, vaqt — `HH:MM`; `...At` ISO-8601 (UTC).
- **Tenant izolyatsiyasi:** bola faqat o'z maktabi/sinfi/o'zining yozuvlarini ko'radi; boshqasi `404`.

## A. Bola uchun e'lonlar

### Xodim tomoni (o'zgarish)

`audience` JSON'ga ixtiyoriy `includeStudents: boolean` (default `false`) qo'shildi. Faqat `SCHOOL` va
`CLASSES` uchun ma'noli; `GUARDIANS` da jim `false`ga keltiriladi (xuddi shu transformda `classIds` ham
tozalanadi). Qabul qiladi: `POST /school/comms/announcements/{drafts,send}`, `PUT .../:id/draft`,
`POST .../:id/send`; qaytaradi: ro'yxat/tafsilot/yuborish javoblaridagi `audience.includeStudents` (har doim bor).
`POST /school/comms/reminders` ham shu sxemani ishlatadi (qiymat qabul qilinadi, lekin eslatmalarda ma'nosi yo'q).

```json
{ "title": "…", "body": "…", "priority": "NORMAL",
  "audience": { "kind": "CLASSES", "classIds": ["<classId>"], "guardianIds": [], "includeStudents": true } }
```

### `GET /api/child/school/announcements?cursor=&limit=`

`limit` 1–50 (default 20). Faqat **SENT** e'lonlar, `includeStudents=true` va auditoriyasi bolaning maktabi
(`SCHOOL`) yoki **hozirgi** sinfini (`CLASSES`) qamrab oladi. Eng yangisi birinchi (`sentAt`, `id` kamayish).
Boshqa sinf/maktab, `GUARDIANS`, qoralama va rejalashtirilgan e'lonlar hech qachon chiqmaydi.

```json
{
  "items": [{
    "id": "…", "title": "…", "body": "…", "priority": "NORMAL",
    "sentAt": "2026-10-20T05:00:00.000Z",
    "author": { "name": "Karimov Akmal", "role": "DIRECTOR" },
    "audienceLabel": "CLASS", "className": "7-A", "read": false
  }],
  "unreadCount": 3,
  "nextCursor": "eyJz…"
}
```
`audienceLabel`: `SCHOOL` | `CLASS`; `className` faqat `CLASS` da (bolaning o'z sinfi). `author.role` — xodim roli
(`DIRECTOR|ADMIN|HOMEROOM|…`), xodim topilmasa `{ "name": "—", "role": null }`. `nextCursor` — opaque; oxirgi sahifada `null`.
Buzilgan kursor → `400 VALIDATION` (`cursor: invalid`).

### `POST /api/child/school/announcements/:id/read` → `200`

Idempotent; birinchi o'qish vaqti saqlanadi. Javob `{ "id": "…", "readAt": "…" }`. Bolaga ko'rinmaydigan e'lon
(boshqa sinf/maktab, qoralama, faqat ota-onalarga) yoki noma'lum id → `404 NOT_FOUND`. O'qildi belgisi
o'quvchi bo'yicha (`school_announcement_student_reads`), ota-ona o'qishi (`Delivery`) bilan aralashmaydi.

## B. Bola davomat tarixi

### `GET /api/child/school/attendance?month=YYYY-MM`

`month` ixtiyoriy (default — joriy oy, Toshkent); noto'g'ri (`2026-13`, `abc`) → `400`. Faqat bolaning o'zi.

```json
{
  "month": "2026-10",
  "days": [{
    "date": "2026-10-19", "status": "PRESENT", "inAt": "08:02", "outAt": "13:30",
    "source": "QR", "confirmed": false, "kiosk": { "inAt": "08:00", "outAt": "13:30" }
  }],
  "summary": { "present": 1, "late": 1, "absent": 1, "leftEarly": 0, "excused": 0, "unknown": 4, "total": 7, "rate": 67 }
}
```
- `status`: `PRESENT|LATE|ABSENT|LEFT_EARLY|EXCUSED|UNKNOWN`. `source`: `QR|KIOSK|MANUAL|SYSTEM`.
- **UNKNOWN** ("Aniqlanmagan"): `source=SYSTEM` va `status=ABSENT` (cron yozgan "kelmadi"), agar **xodim tuzatishi**
  bo'lmasa. Bundan tashqari yozuvi yo'q **o'tgan o'quv kuni** ham `UNKNOWN` (`source: "SYSTEM"`, `inAt/outAt/kiosk: null`);
  qabul sanasidan oldingi, dam olish/bayram kunlari, bugun (yozuv yo'q bo'lsa) va kelajak kunlari ro'yxatga kirmaydi.
- **confirmed** = `source=MANUAL` **yoki** xodim yozgan `SchoolAttendanceCorrection` bor. Tizim tuzatishlari
  (`byStaffId = 'system'`, QR bilan kelganda yoziladi) xodim hisoblanmaydi.
- **kiosk** = shu kunning QR/KIOSK hodisalaridan birinchi `IN` va oxirgi `OUT` (Toshkent `HH:MM`); bunday hodisa
  bo'lmasa `null` (qo'lda `MANUAL` hodisalar hisobga olinmaydi).
- **summary**: faqat o'quv kunlari ≤ bugun; `unknown` — belgilanmagan (ulushga kirmaydi); `rate` = (present+late+leftEarly) /
  (total − unknown), %. Mantiq ota-ona ko'rinishi (`AttendanceParentService`) bilan bir xil (`addCount`/`attendedRate`).

## C. Dars jadvali

Model `SchoolTimetableLesson { classId, weekday 1..6 (Du..Sh), periodNo, subject, room?, teacherName? }`,
`@@unique([classId, weekday, periodNo])`. `subject` — `LearningSubject` kaliti kichik harfda (`math`, `english`, …;
`MATH` yuborilsa `math`ga keltiriladi) yoki erkin nom (≤ 60). `room` ≤ 20, `teacherName` ≤ 80 (bo'sh → `null`).

**Ruxsat `timetable.manage`**: DIRECTOR, ADMIN (butun maktab), HOMEROOM (faqat o'z sinfi). Ko'rish — `classes.view`
(DIRECTOR, ADMIN, HOMEROOM, TEACHER; OWN_CLASS rollar faqat o'z sinfini). `school-panel/src/auth/permissions.ts`
nusxasi sinxronlandi (shu faylgina o'zgardi).

### `GET /api/school/timetable/classes/:classId`
```json
{ "classId": "…",
  "shift": { "id": "…", "name": "1-smena", "start": "08:00", "end": "13:25", "weekdays": [1,2,3,4,5,6],
             "periods": [{ "no": 1, "start": "08:00", "end": "08:45", "kind": "LESSON" }, { "no": 1, "start": "08:45", "end": "08:55", "kind": "BREAK" }] },
  "lessons": [{ "id": "…", "weekday": 1, "periodNo": 1, "subject": "math", "room": "12", "teacherName": "Aliyeva N." }] }
```
(`shift` kontraktdagi `{id,name,periods}` ning ustiga `start/end/weekdays` ham beradi — panel setkasi uchun.)

### `PUT /api/school/timetable/classes/:classId`
Body `{ "lessons": [{ "weekday": 1, "periodNo": 1, "subject": "math", "room": "12", "teacherName": "…" }] }` — sinfning
**butun haftasini bitta tranzaksiyada almashtiradi** (`[]` — jadvalni tozalaydi). Javob — GET bilan bir xil. Tekshiruv:
`weekday` smena o'quv kunlaridan (1..6), `periodNo` — smenadagi **LESSON** davri (BREAK emas), (kun, davr) takrorlanmaydi.
Birinchi xato `400 VALIDATION`: `lessons.<i>.weekday: errors.form.invalidWeekday`, `…periodNo: errors.form.invalidPeriod`,
`…periodNo: errors.form.duplicate`, `…subject|room|teacherName: errors.form.required|tooLong`. Xato bo'lsa eski jadval saqlanadi.
Audit: modul `CLASSES`, amal `timetable.replace` (oldin/keyin). Bir sinf uchun parallel saqlash advisory lock bilan ketma-ket.
Boshqa maktab sinfi → `404`; doiradan tashqari sinf (HOMEROOM/TEACHER) → `403`.

### `GET /api/child/school/timetable?date=YYYY-MM-DD`
`date` default — bugun (Toshkent); haqiqiy bo'lmagan sana → `400`.
```json
{ "date": "2026-10-20", "weekday": 2, "className": "7-A",
  "shift": { "name": "1-smena", "start": "08:00", "end": "13:25" },
  "published": true, "dayOff": null,
  "lessons": [{ "periodNo": 1, "start": "08:00", "end": "08:45", "subject": "math", "room": null, "teacherName": null }] }
```
`published` — sinfda (haftaning istalgan kunida) kamida bitta dars bor (yo'q bo'lsa ilova "jadval kiritilmagan" desin).
`dayOff`: hafta kuni smena o'quv kunlaridan emas → `{ "reason": "WEEKEND" }`; bayram (`SchoolHoliday`) →
`{ "reason": "HOLIDAY", "name": "…" }` (ikkalasi bo'lsa WEEKEND); dam olish kunida `lessons: []`. Vaqtlar smenaning
LESSON davrlaridan; smenadan keyin olib tashlangan davr darsi ko'rsatilmaydi.

## D. Yozma vazifa (rasm bilan topshirish)

### Topshiriq yaratish (o'zgarish)
`POST /api/school/learning/assignments` (`learning.assign`): `materialId: "written"` (yoki `materialKind: "WRITTEN"`) +
`title` (majburiy, ≤ 120) + `estimatedMinutes` (1–240, **har qanday turda** ixtiyoriy). TEST/AUDIOBOOK avvalgidek
(`title` e'tiborga olinmaydi, `null`). Javobga `materialKind`, `title`, `estimatedMinutes` qo'shildi. Xodim ro'yxati
(`GET /school/learning/assignments`): `materialKind: "WRITTEN"`, `materialTitle = title`, `title`, `estimatedMinutes`.

### `GET /api/child/school/assignments` (additiv)
Mavjud maydonlar saqlangan; qo'shildi: `materialKind` (`TEST|AUDIOBOOK|VIDEO|WRITTEN`), `title` (yozma — sarlavha, boshqalar —
katalog nomi), `estimatedMinutes`, `teacherName` (yaratgan xodim F.I.Sh. yoki `null`), `submission`
(faqat WRITTEN, aks holda `null`): `{ "status": "SUBMITTED|ACCEPTED|RETURNED", "submittedAt", "reviewedAt", "reviewNote", "photoCount" }`.
WRITTEN uchun `done = (submission.status === 'ACCEPTED')`. Ko'rinish oynasi o'zgarmagan: bolaning sinfi, muddati o'tganlari 7 kun.

### `POST /api/child/school/assignments/:id/submission` (multipart) → `200`
- Fayllar: **1–5** ta rasm (maydon nomi ixtiyoriy, tavsiya `files`), har biri **≤ 8 MB**. Format faqat **magic bytes**
  bo'yicha: JPEG, PNG, WebP, HEIC/HEIF (klientning Content-Type/fayl nomiga ishonilmaydi).
- Matn maydonlari: `comment` (ixtiyoriy, ≤ 1000), `requestId` (ixtiyoriy UUID — idempotentlik).
- Faqat bolaga ko'rinadigan **WRITTEN** topshiriq (o'z sinfi, 7 kundan ortiq kechikmagan); aks holda `404 ASSIGNMENT_NOT_FOUND`.
- Holat ACCEPTED bo'lmasa ruxsat: qayta yuborish **rasm va izohni almashtiradi**, holat `SUBMITTED`ga qaytadi, baho
  maydonlari tozalanadi, eski MinIO obyektlari o'chadi. ACCEPTED → `409 { code: "ALREADY_ACCEPTED" }`.
- **Idempotent:** shu (topshiriq, bola) uchun saqlangan `requestId` bilan bir xil so'rov takrorlansa, yangi yuklash
  qilinmaydi — joriy topshiriq qaytadi (ACCEPTED bo'lsa ham). Parallel so'rovlar advisory lock bilan ketma-ket.
- EXIF/GPS JPEG, PNG, WebP'dan olib tashlanadi (yo'nalish saqlanadi). HEIC o'zgarishsiz saqlanadi.
- Xatolar: fayl yo'q / 5 tadan ko'p / `comment` > 1000 / `requestId` UUID emas → `400 VALIDATION`
  (`files: errors.form.selectAtLeastOne|tooMany`, `comment: errors.form.tooLong`); rasm emas → `415 UNSUPPORTED_IMAGE`;
  fayl > 8 MB → `413 FILE_TOO_LARGE`; jarayonda bir vaqtda 6 tadan ko'p yuklash ketayotgan bo'lsa → `429 { code: "BUSY" }`
  (xotirani himoya qiladi; klient shu `requestId` bilan qayta urinsin).

```json
{ "id": "…", "assignmentId": "…", "status": "SUBMITTED", "comment": "Tayyor",
  "submittedAt": "…", "reviewedAt": null, "reviewNote": null,
  "photos": [{ "id": "…", "url": "https://…/api/school/homework/photos/<id>?exp=…&sig=…", "contentType": "image/jpeg", "size": 123456, "position": 0 }] }
```

### Xodim: `GET /api/school/learning/assignments/:id/submissions` (`learning.view`)
ADMIN/DIRECTOR — topshiriqning barcha sinflari, HOMEROOM — faqat o'z sinflari (umuman kesishmasa `403`).
Faqat WRITTEN (aks holda `404`). Arxivlanmagan o'quvchilar, sinf → familiya bo'yicha.
```json
{ "assignment": { "id", "title", "dueDate", "estimatedMinutes", "note", "classIds": ["…"] },
  "counts": { "total": 3, "submitted": 1, "accepted": 0, "returned": 0, "missing": 2 },
  "students": [{ "studentId", "name", "classId", "className",
                 "submission": null | { …yuqoridagi topshiriq…, "reviewedByStaffId": null, "photos": [{ "url": "…" }] } }] }
```

### Xodim: `POST /api/school/learning/submissions/:id/review` → `200`
Body `{ "status": "ACCEPTED" | "RETURNED", "note": "≤ 500" }`. Ruxsat **`learning.assign`** (ADMIN, HOMEROOM o'z sinfi);
DIRECTOR ko'ra oladi, lekin baholay olmaydi (`403`). Istalgan holatdan qayta baholash mumkin. Bola o'sha orada qayta
yuborgan bo'lsa (`submittedAt` o'zgargan) → `409`. Javob — topshiriq (`reviewedByStaffId` bilan). Audit: `LEARNING / homework.review`
(izoh matni auditga yozilmaydi).

### Rasm proksisi: `GET /api/school/homework/photos/:photoId?exp=&sig=` (`@Public`)
HMAC imzo (kalit `JWT_ACCESS_SECRET`dan **alohida maqsad belgisi** `school-homework-photo:v1` bilan ajratilgan; yangi env yo'q).
Muddat soat chegarasiga yaxlitlanadi → havola 1–2 soat amal qiladi va soat ichida o'zgarmaydi (kesh). Imzo noto'g'ri/muddati
o'tgan → `403`; rasm yoki obyekt yo'q → `404`; MinIO'ning o'zi ishlamasa → `503` (logga yoziladi, 404 emas). Javob: saqlangan `Content-Type`, `Cache-Control: private, max-age=3600`,
`X-Content-Type-Options: nosniff`. Xodim va bola javoblari shu havolalarni beradi (MinIO presigned URL prod'da buzuq).

### Ma'lumotlarni o'chirish
- To'rt yo'lda ham shu bolaga bog'langan o'quvchining barcha topshiriqlari va MinIO rasmlari o'chadi, o'quvchi yozuvi qoladi:
  bola o'z akkauntini o'chirsa (`ChildDataPurgeService.deleteChildAccount`), ota-ona bola profilini o'chirsa
  (`purgeChildProfile`), ota-ona o'z akkauntini o'chirsa (`UsersService.deleteAccount`, PARENT) va admin foydalanuvchini
  butunlay o'chirsa (`AdminUsersService.deleteUser`, PARENT yoki CHILD). Topshiriqlar DB'dan **avval** o'chiriladi, chunki
  `child` o'chganda o'quvchi bog'lanishi (`childId`) `SetNull` bo'ladi. Umumiy yordamchilar: `school/homework/homework-purge.ts`.
- Topshiriq (`DELETE /school/learning/assignments/:id`) o'chirilsa — uning topshiriqlari (cascade) va rasm obyektlari ham o'chadi.
- O'quvchini arxivlash topshiriqlarni **o'chirmaydi** (qayta tiklanadigan amal). Hozir o'quvchini qattiq o'chiradigan yo'l yo'q;
  kelajakda qo'shilsa DB qatorlari FK cascade bilan ketadi, MinIO obyektlari uchun `homeworkKeysOf` + `HomeworkStorageService.deleteKeys` ishlatilsin.

## Qarorlar va og'ishlar

1. **Bog'lanmagan bola → 404 `NOT_ENROLLED`** (yangi yo'llar); mavjud assignments ro'yxati `[]` qoldi.
2. **`confirmed`** tizim (`system`) tuzatishlarini xodim deb hisoblamaydi; UNKNOWN qoidasi shunga mos.
3. **Yozuvsiz o'tgan o'quv kuni = UNKNOWN** (kontraktda aniq aytilmagan; "skanerlanmagan kun — Aniqlanmagan" konsepsiyasidan).
4. **`weekday` 1..6** (kontrakt), 7 (yakshanba) rad etiladi.
5. **Bucket nomi `farzandim-school-homework`** (boshqa bucket'lardagi `farzandim-` prefiksiga mos); `ensureBuckets` o'zi yaratadi.
6. **Baholash `learning.assign`** talab qiladi (kontraktda ruxsat aytilmagan; yozuv amali — "ko'rish"dan kuchliroq).
7. `POST …/submission` doim `200` (yaratish ham, almashtirish ham).
8. Yozma bo'lmagan turlarda `title` saqlanmaydi (ko'rinadigan nom — katalogdan, "avvalgidek").
9. Submission'ga ko'rinish oynasi ro'yxatniki bilan bir xil (`assignment-visibility.ts`): 7 kundan ortiq kechikkan vazifa topshirilmaydi.
10. HEIC: qayta kodlanmaydi, EXIF'i tozalanmaydi; brauzerda (panel) ko'rinmasligi mumkin — panel `contentType` bo'yicha yuklab olish havolasi ko'rsatsin.
11. `audience.includeStudents` har doim javobda bor — mavjud e2e (`audience` `toEqual`) shunga moslab yangilandi.
12. Yangi audit modul qo'shilmadi: dars jadvali → `CLASSES`, baholash → `LEARNING`. Yangi i18n kalitlari panel uchun:
    `errors.form.invalidWeekday|invalidPeriod|duplicate|tooMany|outOfRange`.

## Deploy eslatmalari

- `main`ga merge = prod deploy (+ `prisma migrate deploy`). Migratsiya faqat qo'shuvchi, mavjud ma'lumotga tegmaydi, orqaga qaytarish:
  yangi jadvallarni `DROP` qilish va ikkita ustunni olib tashlash yetarli (eski kod ularni ishlatmaydi).
- **nginx**: `client_max_body_size` kamida ~45 MB bo'lishi kerak (`POST /api/child/school/assignments/*/submission` 5 × 8 MB + maydonlar).
  Repoda prod nginx konfigi yo'q — serverda tekshiring.
- Yangi env yo'q: imzo `JWT_ACCESS_SECRET`, havola bazasi `PUBLIC_BASE_URL` (default `https://farzandimedu.uz`).
  Bucket `farzandim-school-homework` MinIO'da birinchi ishga tushishda yaratiladi.
- Rasm proksisi to'liq obyektni xotiraga o'qiydi (≤ 8 MB) — kuchli yuklama kutilsa `getObjectStream`ga o'tish mumkin.
- Panel: `timetable.manage` ruxsatini ko'rsatadigan UI (dars jadvali sahifasi) va yozma vazifa ro'yxati/baholash UI hali yo'q (backend tayyor).

## Testlar

Unit: `homework-image`, `homework-signature`, `homework-gate`, `homework-view`, `child-announcements-view`, `attendance-child-view`, `timetable-rules`,
`timetable-view`, `school-learning.schemas`, `child-data-purge`. E2E (haqiqiy Postgres): `school-child-announcements`,
`school-child-attendance`, `school-timetable`, `school-homework-{assignments,submit,review}`; xotiradagi MinIO fake'i
`test/e2e/school-child-fixtures.ts` (`createTestApp({ storage })`).
