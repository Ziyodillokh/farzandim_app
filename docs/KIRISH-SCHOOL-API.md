# Kirish K2: maktab o'quvchi kodi (ikki o'rin), tasdiqlash va tuzatish — backend kontrakti

Branch: `feat/kirish-school` (origin/main `8a511d50`'dan). Migratsiya: **`20261109100000_kirish_school`** — FAQAT qo'shuvchi:
3 ta yangi jadval (`school_student_invites`, `school_link_corrections`, `school_guardian_reviews`), ularning indekslari / begona
kalitlari va 5 ta qisman unique indeks + 3 ta CHECK (Prisma sxemasi ifodalay olmaydi, `migrate diff` ularni drift deb hisoblamaydi). Mavjud jadval,
ustun va qatorlarga tegilmaydi (UPDATE / DELETE yo'q). Hamma yo'l `/api` prefiksi bilan. Manba: `kirish-contract.md` K2 bo'limi
(qarorlar D1–D7).

> Hech narsa buzilmaydi: 8 belgili vasiy kodlari (`school_guardians.invite_code`, 7 kun) va ularning oqimi aynan avvalgidek;
> `PUT /parent/school/students/:id/child`, `requireEnrolledStudent` va barcha mavjud maktab e2e testlari o'zgarishsiz o'tadi.

## 0. Umumiy qoidalar

- **Xatolar:** `{ "statusCode": 404, "code": "CODE_INVALID", "message": "…" }`. Tekshiruv xatosi: `400 { code: "VALIDATION",
  message: "maydon: errors.form.x" }`. Maktab / o'quvchi nomi xato matnlarida HECH QACHON yo'q.
- **Kim:** xodim paneli (`school-jwt`, ruxsat `guardians.link`, sinf rahbari — faqat o'z sinfi); bola ilovasi (CHILD tokeni);
  ota-ona ilovasi (PARENT tokeni). Rol mos kelmasa `403`, tokensiz `401`.
- **Kod:** 6 raqam (`"048213"`, bosh nollar mumkin), kriptografik tasodif, **24 soat**; faol (yopilmagan va muddati
  o'tmagan) kodlar orasida yagona; bitta o'quvchida bitta faol kod. Kiritishda bo'shliq va chiziqcha farqsiz
  (`"048 213"`, `"048-213"`).
- **Ikki o'rin:** *o'quvchi o'rni* (bola ilovasi) va *ota-ona o'rni* (Parvoz Parents). Ikkalasi band bo'lsa kod yopiladi.
- **6 raqamli kod O'ZI hech qachon vasiylik yoki tasdiqlangan bog'lanish bermaydi.** Bola kodi — `UNDER_REVIEW`; ota-ona kodi
  faqat maktab allaqachon ishongan ota-onani ulaydi (o'zi vasiy yoki maktab kiritgan yozuvning telefoni mos), qolganlari
  xodim tasdig'ini kutadi (§4, §5).
- **Nomlar:** maktab / sinf / o'quvchi nomi bola javoblarida FAQAT `CONFIRMED` holatda (§3.2).
- **Vaqt:** `…At` — ISO-8601 (UTC).

## 1. Holatlar (D6)

Bolaning o'quvchi bilan bog'lanishi (`student.status`):

| Holat | Ma'nosi | `SchoolStudent.childId` | Maktab ma'lumoti bolaga |
|---|---|---|---|
| `NONE` | kod kiritilmagan / rad etilgan / uzilgan | — | yopiq (`NOT_ENROLLED`) |
| `UNDER_REVIEW` | bola kod kiritdi, tasdiq kutilmoqda | o'rnatilmagan | **yopiq** (`NOT_ENROLLED`) |
| `CONFIRMED` | tasdiqlangan | bola | ochiq |
| `CORRECTION` | tasdiqlangan, lekin bola "maktab / sinf noto'g'ri" dedi (ochiq so'rov) | bola | **yopiq** (`UNDER_REVIEW`) |

Bola kodi o'z-o'zidan ishonch bermaydi (6 raqamli maydon kichik): `UNDER_REVIEW` → `CONFIRMED` quyidagilardan biri bilan:

1. bolaning **o'z ota-onasi** 6 raqamli kod bilan o'quvchining **ulangan vasiysi** bo'ladi (kiritishdan oldin yoki keyin;
   bola kutayotgan o'quvchining har qanday kodi) — avtomatik. Ota-onani kod emas, maktab ishonchi vasiy qiladi: telefoni
   mos kelsa darhol, aks holda xodim `GUARDIAN` so'rovini tasdiqlaganda;
2. bola kodni kiritayotganda bolaning o'z ota-onasi allaqachon o'quvchining **ulangan vasiysi** (`LINKED` `SchoolGuardian`,
   masalan 8 belgili kod orqali) — darhol. Tekshiruv **jonli**: ota-ona aloqasi keyin uzilgan bo'lsa yoki vasiylik hali
   xodim ko'rigida bo'lsa, eski "ota-ona o'rni" ishonch bermaydi;
3. xodim `POST /school/link-requests/:id/confirm` qiladi;
4. ota-ona eski `PUT /parent/school/students/:id/child` bilan bolani moslaydi (kod yozuvi o'zi `CONFIRMED` bo'ladi).

`CONFIRMED` bog'lanish ota-ona PUT'idagi invariantlar bilan o'rnatiladi: bola faqat bitta faol o'quvchiga ulanadi
(`ALREADY_ENROLLED`), o'quvchi boshqa **oila** farzandiga ulangan bo'lsa `STUDENT_LINKED_ELSEWHERE` (shu oilaning
aka-ukasi almashtiriladi); arxivdagi / to'xtatilgan maktabdagi eski bog'lanishdan bola ko'chiriladi.

## 2. Xodim: o'quvchi kodi

Ruxsat — `guardians.link` (direktor, administrator, sinf rahbari). Sinf rahbari faqat o'z sinfi o'quvchisiga (boshqasi
`403`); boshqa maktab o'quvchisi / noma'lum id — `404`; arxivdagi o'quvchi — `409 { code: "STUDENT_ARCHIVED" }` (K1 ham shu
kodni ishlatadi); `teacher`, `duty`, `psychologist` — `403`.

### `POST /api/school/students/:studentId/invite-code`

Body yo'q. Oldingi yopilmagan kod(lar) yopiladi (eski kod darhol yaroqsiz). Audit: `student.inviteCode` (kodning o'zi yozilmaydi).

`201`

```json
{ "code": "048213", "expiresAt": "2026-11-10T09:30:12.345Z" }
```

### `GET /api/school/students/:studentId/invite-code`

`200` — faol kod va ikki o'rin holati; faol kod yo'q (hech qachon yaratilmagan, muddati o'tgan yoki yopilgan) bo'lsa **JSON `null`**
(tana aynan `null`).

```json
{
  "id": "5d3c…",
  "code": "048213",
  "expiresAt": "2026-11-10T09:30:12.345Z",
  "createdAt": "2026-11-09T09:30:12.345Z",
  "student": { "status": "FREE", "usedAt": null },
  "parent": { "status": "USED", "usedAt": "2026-11-09T10:02:44.001Z" }
}
```

`student.status`: `FREE` (bola kiritmagan) | `UNDER_REVIEW` (bola kiritdi, tasdiq kutilmoqda) | `CONFIRMED`.
`parent.status`: `FREE` | `USED` (ota-ona o'rni, vasiylik so'rovi xodim ko'rigida bo'lsa ham, `USED`). Ikkala o'rin band bo'lsa
kod yopiladi va `GET` `null` qaytaradi (yangi kod kerak).
Ota-ona akkaunti o'chsa, uning o'rni o'zi bo'shaydi.

## 3. Bola ilovasi

CHILD tokeni. Bola profili (`Child`) topilmasa `404 CHILD_NOT_FOUND`.

### 3.1 `POST /api/child/school/link`

```json
{ "code": "048213" }
```

`200` — bog'lanish holati tanasi (§3.2). Muvaffaqiyatda **o'quvchi o'rni** band bo'ladi:

- bolaning o'z ota-onasi HOZIR o'quvchining ulangan (`LINKED`) vasiysi bo'lsa → `CONFIRMED`
  (`SchoolStudent.childId` o'rnatiladi, nomlar qaytadi); ota-ona kodning ota-ona o'rnini band qilgan, lekin vasiylik xodim
  ko'rigida bo'lsa — hali `UNDER_REVIEW` (`parent.status` ham `UNDER_REVIEW`);
- aks holda `UNDER_REVIEW` (nomlar yo'q) va xodimga `LINK_REVIEW` bildirishnomasi (§7).

Qoidalar:

- **Takroriy so'rov idempotent:** bola shu kodni allaqachon kiritgan bo'lsa (javob yo'qolgan bo'lsa) — `200`, o'zgarishsiz
  (kod yopilgan bo'lsa ham, muddati o'tmaguncha).
- **Almashtirish:** `UNDER_REVIEW` dagi bola boshqa yaroqli o'quvchi kodini kiritsa, oldingi kutayotgan o'rin bo'shaydi va
  uning bildirishnomasi o'chadi.
- Bola allaqachon `CONFIRMED` bo'lsa, **o'z** o'quvchisining kodini qayta kiritish `200`; boshqa HAR QANDAY kod (yaroqli ham,
  yaroqsiz ham) — bir xil `409 ALREADY_ENROLLED` (javob kodni tekshirish vositasi bo'lmasin). `CORRECTION` ham `CONFIRMED`
  hisoblanadi (xodim hal qilmaguncha boshqa kod kiritib bo'lmaydi).

Xatolar:

| Holat | Javob |
|---|---|
| Noto'g'ri / muddati o'tgan / yopilgan kod; o'quvchi o'rni boshqa bolada; o'quvchi boshqa bolaga tasdiqlangan | `404 { code: "CODE_INVALID" }` — hammasi **bir xil** (sabab ajratilmaydi, nomlar yo'q) |
| Allaqachon `CONFIRMED` (§ yuqorida) | `409 { code: "ALREADY_ENROLLED" }` |
| 15 daqiqada **5 ta** noto'g'ri kod (bola bo'yicha) yoki **60 ta** (IP bo'yicha; maktab Wi-Fi'si / NAT) | `429 { code: "LOCKED", retryAfterSeconds: 842 }` — blokda to'g'ri kod ham 429 |
| Kod formati noto'g'ri (6 raqam emas), `code` yo'q | `400 { code: "VALIDATION", message: "code: errors.school.studentCodeFormat" }` (sanalmaydi) |

Limit faqat **noto'g'ri urinishlarni** (`CODE_INVALID`) sanaydi; muvaffaqiyatli kiritish limitni yemaydi, lekin oldingi
xatolar oynada (15 daqiqa) saqlanadi. 5 ta xatodan keyingi (6-chi) urinish `LOCKED`. "Tekshir -> bajar -> hisobla" bola va
IP bo'yicha **ketma-ket** bajariladi: parallel so'rovlar (masalan 25 ta bir vaqtda) ham aynan 5 ta xatodan keyin bloklanadi.
Hisob xotirada (bitta instance; qayta ishga tushganda nolga tushadi).

Qo'shimcha: bitta bola 10 daqiqada ko'pi bilan 30 ta so'rov yubora oladi (`schoolLink` limiti, **bola** bo'yicha — IP bo'yicha
emas, maktab Wi-Fi'sidagi boshqa bolalar zarar ko'rmasin); oshsa umumiy `429` (`LOCKED` shaklida emas — ilova uni oddiy
"keyinroq urinib ko'ring" deb ko'rsatsin).

### 3.2 `GET /api/child/school/link-status`

```json
{
  "student": { "status": "NONE", "schoolName": null, "className": null },
  "parent": { "status": "NONE" },
  "expiresAt": null
}
```

- `student.status`: `NONE` | `UNDER_REVIEW` | `CONFIRMED` | `CORRECTION` (§1). `schoolName` (`School.name`) va `className`
  (`SchoolClass.name`, masalan `"6-B"`) **faqat `CONFIRMED`** da; qolgan hammasida `null`.
- `parent.status` — bolaning O'Z ota-onasi tomoni: `CONFIRMED` (ota-ona HOZIR o'quvchining ulangan vasiysi) |
  `UNDER_REVIEW` (**yangi**: ota-ona kodning ota-ona o'rnini band qildi, lekin vasiylik xodim tasdig'ini kutmoqda —
  ilova "maktab tekshirmoqda" ko'rsatadi) | `PENDING` (kod hali faol, ota-ona kiritmagan) | `EXPIRED` (kod muddati o'tgan
  yoki yopilgan, ota-ona vasiy emas — masalan ota-ona o'rnini boshqa ota-ona band qilgan yoki so'rovi rad etilgan) |
  `NONE` (bola kod kiritmagan).
- `expiresAt` — bola kiritgan kodning muddati (`parent.status` `PENDING` yoki `EXPIRED` bo'lganda), aks holda `null`.

Misol (kod kiritildi, ota-ona hali kiritmagan):

```json
{
  "student": { "status": "UNDER_REVIEW", "schoolName": null, "className": null },
  "parent": { "status": "PENDING" },
  "expiresAt": "2026-11-10T09:30:12.345Z"
}
```

### 3.3 `POST /api/child/school/correction` (A08)

Faqat **tasdiqlangan** bog'lanish uchun (`NONE` / `UNDER_REVIEW` bolada tuzatadigan narsa yo'q → `404 NOT_ENROLLED`).

```json
{ "reason": "WRONG_SCHOOL_OR_CLASS", "note": "Men 7-B sinfdaman", "clientRequestId": "3f9c1c1e-6a1b-4c1e-9d5e-0a3f4b6c7d8e" }
```

`reason` — hozircha faqat `WRONG_SCHOOL_OR_CLASS`; `note` — ixtiyoriy, bo'sh joylar olib tashlanadi, ≤ 300 belgi (oshsa
`400`, kesilmaydi); `clientRequestId` — **UUID** (majburiy).

`201`

```json
{ "id": "9b8f…", "status": "OPEN" }
```

- **Idempotent:** bir xil `clientRequestId` — o'sha so'rov (qayta yaratilmaydi, bildirishnoma ikkilanmaydi; hal bo'lgan
  bo'lsa joriy `status` bilan). Bolada bitta ochiq so'rov: ochiq so'rov bor paytda yangi `clientRequestId` ham o'sha ochiq
  so'rovni qaytaradi.
- **Kuniga 5 ta** yangi so'rov (24 soat oynasi): oshsa `429 { code: "TOO_MANY_REQUESTS" }`.
- Xatolar: `400 VALIDATION` (`reason:` / `note:` / `clientRequestId:` bilan boshlanadigan `message`), `404 NOT_ENROLLED`.

**Ochiq (`OPEN`) bo'lganda bolaning maktab ma'lumoti yopiq** (xodim hal qilguncha; `link-status` — `CORRECTION`):

- `requireEnrolledStudent` ishlatadigan yo'llar → `404 { code: "UNDER_REVIEW" }` (eski ilovalar uni "ulanmagan" deb qabul
  qiladi): dars jadvali (`/child/school/timetable`), e'lonlar (`/announcements`, `…/:id/read`), oylik davomat
  (`/attendance`), psixolog murojaati (`/care/requests…`, `/care/contact`, anonim so'rovnoma javobi), yozma vazifa
  topshirish;
- "ulanmagan" shaklini qaytaradigan yo'llar o'zgarmagan shaklda bo'sh: `GET /child/school/today` → `{ "today": null }`,
  `GET /child/school/assignments` → `[]`, `GET /child/school/assessments` → `{ "enrolled": false, "assignments": [] }`,
  `GET /child/school/care/survey` → `{ "enrolled": false, … }`, `POST /child/school/check-in` → `403 NOT_ENROLLED`.

Maktab rejimi (qurilma cheklovlari) va bolaning o'z ma'lumoti (testlar, DON) bunga kirmaydi — ular maktab ma'lumoti emas.

## 4. Ota-ona ilovasi: `POST /api/parent/school/link` (mavjud endpoint)

Endi 6 raqamli o'quvchi kodini ham qabul qiladi (ota-ona o'rni). **8 belgili vasiy kodlari aynan avvalgidek ishlaydi.**

```json
{ "code": "048213" }
```

`200` — mavjud bog'lanishlar shakli (`{ links: […], children: […] }`, `GET /parent/school/links` bilan bir xil, §4.1).
6 raqamli kod bilan uch holat — **kod o'zi vasiylik bermaydi**:

1. **(a) ota-ona allaqachon shu o'quvchining vasiysi** (`userId`) — o'zgarishsiz;
2. **(b) hech kimga ulanmagan, maktab kiritgan vasiy yozuvining telefoni ota-onaning HAQIQIY telefoniga mos** (oxirgi 9 raqam;
   Telegram `tg:…` soxta telefoni hech qachon) — maktab bu telefonga allaqachon ishongan: yozuv ulanadi (`LINKED`). Boshqa
   foydalanuvchiga ulangan yozuv hech qachon o'g'irlanmaydi. Audit `guardian.linked`;
3. **(c) aks holda vasiy ULANMAYDI**: xodim tasdig'ini kutuvchi **vasiylik so'rovi** (`SchoolGuardianReview`, `OPEN`)
   yaratiladi, xodimga `GUARDIAN_REVIEW` bildirishnomasi (§7), navbatda `kind: "GUARDIAN"` (§5). Ota-ona o'rni **band**
   hisoblanadi. Tasdiqlanmaguncha ota-ona **vasiy emas** (`SchoolGuardian` yozuvi yo'q) va hech qanday o'quvchi ma'lumoti,
   xabar, davomat, olib ketish va erta ketish so'roviga kira olmaydi (o'quvchiga bog'liq yo'llar `404`, ro'yxatlar bo'sh).

Qolgan qoidalar:

- kodning ota-ona o'rni band bo'ladi; o'quvchi o'rni ham band bo'lsa kod yopiladi;
- (a) / (b) da shu o'quvchida bolasi `UNDER_REVIEW` da kutayotgan bo'lsa (bola — SHU ota-onaning farzandi; u qaysi kod
  bilan kiritgan — xodim kodni qayta yaratgan bo'lsa ham) → bog'lanish `CONFIRMED`. To'siq bo'lsa (o'quvchi boshqa oilaga
  ulangan) ota-onaning kiritishi baribir muvaffaqiyatli, bola `UNDER_REVIEW` da qoladi. (c) da bola xodim tasdig'igacha
  `UNDER_REVIEW` da qoladi va tasdiqlanganda avtomatik `CONFIRMED` bo'ladi;
- takroriy kiritish (shu ota-ona, vasiy yoki so'rovi ochiq) — `200`, o'zgarishsiz (bitta so'rov, bitta bildirishnoma; kod
  yopilgan bo'lsa ham, muddati o'tmaguncha). Xodim kodni qayta yaratgan bo'lsa, yangi kodni kiritish ochiq so'rovni yangi
  ota-ona o'rniga ko'chiradi. Aloqa uzilgach (ota-ona o'zi yoki xodim) shu faol kodni qayta kiritsa — (a)/(b)/(c) qaytadan
  qo'llanadi; kod yopilgan bo'lsa `INVITE_INVALID`;
- **rad etilgan** ota-ona shu kodni qayta kirita olmaydi (`INVITE_INVALID`; xodim bezovta qilinmaydi) — boshqa ota-ona
  bo'shagan o'rinni egallay oladi.

Xatolar (mavjud kodlar, yangisi yo'q): `404 INVITE_INVALID` (noto'g'ri / muddati o'tgan / yopilgan / ota-ona o'rni **boshqa**
ota-onada / shu ota-ona rad etilgan), `429 TOO_MANY_ATTEMPTS`, `400 VALIDATION` (format: 8 belgi YOKI 6 raqam). Limit
avvalgidek va **ikkala tur kod uchun umumiy**: foydalanuvchiga 30 daqiqada 5 ta, IP'ga 30 ta noto'g'ri urinish (bola endpointi
kabi ketma-ket hisoblanadi — parallel so'rovlar limitni aylanib o'ta olmaydi).

### 4.1 `GET /api/parent/school/links` (va `POST /link`, `PUT /students/:id/child` javoblari)

Shakl o'zgargani yo'q, faqat **qo'shimcha maydonlar** (eski ilovalar ularni e'tiborsiz qoldiradi; `guardianId`siz element
eski ilovada ko'rsatilmaydi):

```json
{
  "links": [
    {
      "status": "LINKED",
      "guardianId": "…",
      "reviewId": null,
      "fullName": "Karimova Malika",
      "relation": "MOTHER",
      "linkedAt": "2026-11-09T10:02:44.001Z",
      "requestedAt": null,
      "school": { "id": "…", "name": "24-maktab", "shortName": "24", "city": "Toshkent", "logo": null },
      "students": [{ "id": "…", "fullName": "Karimov Aziz", "className": "7-A", "childId": null, "linkedBy": "NONE" }]
    },
    {
      "status": "PENDING_REVIEW",
      "guardianId": null,
      "reviewId": "9b8f…",
      "fullName": "Karimova 1",
      "relation": "OTHER",
      "linkedAt": null,
      "requestedAt": "2026-11-09T10:05:00.000Z",
      "school": { "id": "…", "name": "24-maktab", "shortName": "24", "city": "Toshkent", "logo": null },
      "students": []
    }
  ],
  "children": [{ "id": "…", "name": "Aziz" }]
}
```

- `status`: `LINKED` (vasiy) | **`PENDING_REVIEW`** (6 raqamli kod kiritilgan, vasiylik xodim tasdig'ini kutmoqda — ilova
  "maktab tasdig'i kutilmoqda" ko'rsatadi). Mavjud elementlarga `status: "LINKED"`, `reviewId: null`, `requestedAt: null`
  qo'shildi.
- `PENDING_REVIEW` elementida **o'quvchi ma'lumoti HECH QACHON yo'q** (`students: []`): ism, sinf, id — tasdiqdan keyingina.
  Faqat maktab (ota-ona kodni olgan maktab) va so'rov vaqti. `fullName` — ota-onaning o'z profil ismi.
- Aloqani uzish (`DELETE /links/:guardianId`) faqat `LINKED` uchun; `reviewId` bilan `404 LINK_NOT_FOUND`.

## 5. Xodim: ulanish so'rovlari

**Ruxsat kaliti: `guardians.link`** (kodda `LINK_REQUESTS_PERMISSION`) — ro'yxat, `confirm` va `reject` (shu jumladan
tuzatish so'rovini hal qilish) uchun bitta kalit. Jadvaldagi hozirgi egalari: direktor, administrator, sinf rahbari.
Sinf rahbari faqat o'z sinfi (ro'yxat filtrlanadi; boshqa sinf so'rovi `403`); boshqa maktab /
noma'lum id — `404`; `teacher`, `duty`, `psychologist` — `403`.

### `GET /api/school/link-requests`

Massiv (sahifalashsiz, ≤ 200), eng eskilari birinchi. Uch tur:

- `REVIEW` — bola kod kiritdi, `UNDER_REVIEW`. `id` = `<kod yozuvi id>:<bola id>` (shaffof emas — o'zgartirmang, o'zicha
  `confirm` / `reject` ga bering): qaror xodim KO'RGAN bolaga bog'lanadi. Kod muddati o'tgan / yopilgan bo'lsa ham xodim
  hal qilmaguncha qoladi;
- `CORRECTION` — bolaning ochiq tuzatish so'rovi (`id` = so'rov UUID'i);
- **`GUARDIAN`** — telefoni maktabga ma'lum bo'lmagan ota-ona 6 raqamli kodni kiritdi, vasiylik tasdiq kutmoqda
  (`id` = vasiylik so'rovi UUID'i).

```json
[
  {
    "id": "5d3c…:7a21…",
    "kind": "REVIEW",
    "createdAt": "2026-11-09T10:01:02.000Z",
    "student": { "id": "…", "fullName": "Karimov Aziz", "classId": "…", "className": "7-A" },
    "child": { "name": "Aziz" },
    "parent": null,
    "parentLinked": false,
    "reason": null,
    "note": null
  },
  {
    "id": "3c41…",
    "kind": "GUARDIAN",
    "createdAt": "2026-11-09T10:05:00.000Z",
    "student": { "id": "…", "fullName": "Karimov Aziz", "classId": "…", "className": "7-A" },
    "child": { "name": "Aziz" },
    "parent": { "name": "Karimova Malika", "maskedPhone": "+998 ** *** 45 67" },
    "parentLinked": false,
    "reason": null,
    "note": null
  },
  {
    "id": "9b8f…",
    "kind": "CORRECTION",
    "createdAt": "2026-11-09T11:20:00.000Z",
    "student": { "id": "…", "fullName": "Rahimov Bobur", "classId": "…", "className": "7-A" },
    "child": { "name": "Bobur" },
    "parent": null,
    "parentLinked": true,
    "reason": "WRONG_SCHOOL_OR_CLASS",
    "note": "Men 7-B sinfdaman"
  }
]
```

`student.classId` va `student.className` — **nullable**: sinfi yo'q o'quvchi (sinf o'chirilgan) uchun ikkalasi ham `null`
(`className` bo'sh qator emas). `child.name` — ota-ona bolaga bergan ism (xodim qaror qilishi uchun); `GUARDIAN` da `child` — shu ota-onaning shu o'quvchida
tasdiq kutayotgan farzandi (bo'lmasa `null`). **`parent`** (yangi maydon; `GUARDIAN` dan boshqa turlarda `null`) — so'rov
yuborgan ota-ona: `name` (profil ismi, bo'lmasa `"Ota-ona"`) va `maskedPhone` — faqat oxirgi 4 raqam ko'rinadigan niqob
(`+998 ** *** 45 67`; haqiqiy telefon yo'q yoki `tg:…` bo'lsa `null`; to'liq telefon hech qachon qaytmaydi).
`parentLinked` — bolaning o'z ota-onasi o'quvchining ulangan vasiysi (ishonch belgisi; `GUARDIAN` da doim `false`).
`fullName` = familiya ism otasining ismi. Arxivdagi o'quvchi so'rovlari va bog'lanishi boshqa
yo'l bilan uzilgan tuzatish so'rovlari ko'rsatilmaydi.

### `POST /api/school/link-requests/:id/confirm` va `…/reject`

Body yo'q. `200 { "id": "…", "kind": "REVIEW" | "CORRECTION" | "GUARDIAN", "status": "CONFIRMED" | "REJECTED" }`.

| | `confirm` | `reject` |
|---|---|---|
| `REVIEW` | `SchoolStudent.childId` o'rnatiladi (ota-ona PUT'idagi invariantlar), bola `CONFIRMED`, bildirishnoma o'chadi. Audit `student.childLinked` | o'quvchi o'rni bo'shaydi (bola `NONE`), bildirishnoma o'chadi. Audit `student.linkRejected`. Kod hali faol bo'lsa haqiqiy bola kirita oladi; kod yopilgan bo'lsa (ikkala o'rin band bo'lgan) — yangi kod yarating |
| `CORRECTION` | bog'lanish **qoladi**, maktab ma'lumoti qayta ochiladi. Audit `student.linkCorrectionKept` | bog'lanish **uziladi** (`SchoolStudent.childId = null`), bolaning kod o'rinlari bo'shaydi, bola `NONE`. Audit `student.childUnlinked` |
| `GUARDIAN` | ota-ona **vasiy** bo'ladi: mos maktab yozuvi (telefon bo'yicha, tasdiq paytidagi holat) ulanadi, bo'lmasa profildan yangi `SchoolGuardian` (`relation: OTHER`, telefon — faqat haqiqiy). Audit `guardian.linked`. Shu ota-onaning farzandi shu o'quvchida `UNDER_REVIEW` da kutayotgan bo'lsa — bog'lanish `CONFIRMED` (audit `student.childLinked`). Bildirishnoma o'chadi | so'rov yopiladi, kod yozuvidagi **ota-ona o'rni bo'shaydi**, hech narsa ulanmaydi, bildirishnoma o'chadi. Audit `guardian.linkRejected`. Kod yopilgan bo'lsa (ikkala o'rin band bo'lgan) qayta ochilmaydi — yangi kod yarating; rad etilgan ota-ona shu kodni qayta kirita olmaydi |

Idempotentlik: bir xil qaror takrori `200` (`CORRECTION` va `GUARDIAN` uchun ham); qarama-qarshi qaror yoki allaqachon hal
bo'lgan so'rov `409 REQUEST_STALE` (arxivdagi o'quvchi ham); rad etilgan `REVIEW` so'rovi ro'yxatdan chiqqani uchun qayta
rad etish `404`. Parallel `confirm` / `reject` — aynan bittasi yutadi (ikkinchisi `409 REQUEST_STALE`), parallel ikkita
`confirm` — bitta vasiy yozuvi. Xodim ko'rgan `REVIEW` so'rovi eskirgan bo'lsa
(rad etilgach shu kodni BOSHQA bola kiritgan) — `409 REQUEST_STALE`: eski id yangi bolaga hech qachon tegmaydi. Boshqa xatolar: `409 STUDENT_LINKED_ELSEWHERE`
(o'quvchi boshqa oila farzandiga ulangan), `409 ALREADY_ENROLLED` (bola boshqa faol o'quvchiga ulangan) — `REVIEW` ni
`confirm` qilishda; xodim rad etib o'quvchi o'rnini bo'shatishi mumkin.

## 6. Ota-ona PUT'i va qayta bog'lanish bilan o'zaro ta'sir

`PUT /parent/school/students/:id/child` (mavjud) endi bog'lanish o'rnatilganda kod yozuvlarini tozalaydi (javob shakli
o'zgarmagan): shu bolaning o'quvchidagi kutayotgan yozuvi `CONFIRMED`, boshqa o'quvchilardagi o'rinlari va shu o'quvchidagi
**boshqa** bolalarning kutayotgan o'rinlari bo'shaydi, bolaning ochiq tuzatish so'rovlari `CANCELLED` (eskirgan so'rov va
"UNDER_REVIEW" qayta tirilmaydi). Bog'lanish uzilganda — ota-ona `PUT … { childId: null }` / aka-ukani almashtirish /
`DELETE /parent/school/links/:guardianId`, yoki xodim `POST /school/guardians/:id/unlink` — uzilgan bolaning kod o'rinlari
bo'shaydi (tasdiqlangan yozuv qayta `UNDER_REVIEW` bo'lmaydi, kodni qayta kiritish mumkin), ochiq tuzatish so'rovi `CANCELLED`
bo'ladi va bildirishnomasi o'chadi.

## 7. Xodim bildirishnomalari

`SchoolStaffNotification` (`GET /school/notifications/feed`): `LINK_REVIEW` (bola kod kiritdi), `LINK_CORRECTION`
(tuzatish so'rovi) va **`GUARDIAN_REVIEW`** (ishonchsiz ota-ona 6 raqamli kod kiritdi). `params` aynan
`{ studentName, className }` (bola / ota-ona ismi, telefon, kod, izoh, id'lar yo'q). `GUARDIAN_REVIEW` id'si
`guardian-review:<so'rov id>`. Yozuv so'rov hal
bo'lganda (tasdiq, rad, ota-ona orqali tasdiq, almashtirish, bekor, ma'lumot o'chirish) o'chadi.

**Oluvchilar — so'rovni haqiqatan hal qila oladigan xodimlar** (rol nomlari qattiq yozilmagan): o'quvchi maktabining
**faol** xodimlari, ularda `guardians.link` ruxsati bor (rol/ruxsat jadvali bo'yicha) va o'quvchi sinfi ularning doirasida
(`SCHOOL` doirali rollar — hammasi; sinf doirali rol — faqat o'z sinflari; sinfsiz o'quvchi — faqat `SCHOOL` doirali
rollar). Tekshiruv `confirm` / `reject` endpointlaridagi `assertCan` + `assertClassInScope` bilan bir xil funksiyalar
(`actorCan`, `allowedClassIds`) orqali. Hozirgi jadvalda: direktor(lar), administrator(lar) va o'quvchi sinfining sinf
rahbari. Sinf rahbarida ruxsat bo'lmasa, sinfi doirada bo'lsa ham bildirishnoma olmaydi (endpointlari ham unga yopiq).
**Hech kim mos kelmasa — maktabning faol direktorlari** (ruxsati bo'lmasa ham: e'tiborsiz qolmasin); faol direktor ham
bo'lmasa bildirishnoma yozilmaydi (so'rovning o'zi saqlanadi va xodim tiklangach navbatda ko'rinadi). Oluvchilar
yozuv yaratilganda `staffIds` bilan nishonlanadi (rol sharti ham saqlanadi) — keyin qo'shilgan xodim eskilarini lentada emas,
so'rovlar sahifasida ko'radi.

```json
{
  "id": "link-review:5d3c…",
  "kind": "LINK_REVIEW",
  "at": "2026-11-09T10:01:02.000Z",
  "tone": "warning",
  "params": { "studentName": "Karimov Aziz", "className": "7-A" },
  "subject": null,
  "href": "/students/link-requests"
}
```

`LINK_CORRECTION` id'si `link-correction:<so'rov id>`, `GUARDIAN_REVIEW` — `guardian-review:<so'rov id>`; `tone` uchalasida `warning`;
`href` uchalasida `"/students/link-requests"` ("Ulanish soʻrovlari" sahifasi; boshqa lenta turlaridagi `/attendance/early-exit`
kabi — prefikssiz panel yo'li). `params.className` sinfsiz o'quvchida bo'sh qator (`""`).
Lenta (`FEED_LIMIT` = 30) ommaviy ulanishlarda to'lib ketmasligi uchun har tur (`LINK_REVIEW`, `LINK_CORRECTION`,
`GUARDIAN_REVIEW`) bo'yicha eng yangi **10 tasi** ko'rsatiladi
(to'liq navbat — `GET /school/link-requests`).

## 8. Audit (`SchoolAuditLog`)

| `action` | `module` | Kim | `params` |
|---|---|---|---|
| `student.inviteCode` | `GUARDIANS` | xodim | `{ name }` (kod yozilmaydi) |
| `student.linkRequested` | `STUDENTS` | "Bola ilovasi" | `{ name }` |
| `student.childLinked` (mavjud kalit) | `STUDENTS` | xodim / "Bola ilovasi" / "Ota-ona: …" | `{ name }` |
| `student.linkRejected` | `STUDENTS` | xodim | `{ name }` |
| `student.linkCorrection` | `STUDENTS` | "Bola ilovasi" | `{ name }` |
| `student.linkCorrectionKept` | `STUDENTS` | xodim | `{ name }` |
| `student.childUnlinked` (mavjud kalit) | `STUDENTS` | xodim | `{ name }` |
| `guardian.linked` (mavjud kalit) | `GUARDIANS` | "Ota-ona: …" (telefon mos) / xodim (tasdiq) | `{ name }` (vasiy ismi) |
| `guardian.reviewRequested` | `GUARDIANS` | "Ota-ona ilovasi" | `{ name }` (o'quvchi) |
| `guardian.linkRejected` | `GUARDIANS` | xodim | `{ name }` (o'quvchi) |

`name` = `"Familiya Ism"` (o'quvchi / vasiy). Bola ismi, ota-ona telefoni va izoh auditga yozilmaydi. Panel tarjimasi
uchun yangi kalitlar: `student_inviteCode`, `student_linkRequested`, `student_linkRejected`, `student_linkCorrection`,
`student_linkCorrectionKept`, `guardian_reviewRequested`, `guardian_linkRejected`.

## 9. Ma'lumotlarni o'chirish

Bola profili / akkaunti o'chirilganda (`DELETE /users/me` — bola yoki ota-ona, `DELETE /children/:id`, admin
`DELETE /admin/users/:id`) bolaning kod yozuvlari (`SchoolStudentInvite.studentChildId`), tuzatish so'rovlari va ularga
bog'liq `LINK_REVIEW` / `LINK_CORRECTION` bildirishnomalari o'chadi (`link-purge.ts`). Ota-ona akkaunti o'chsa (`DELETE
/users/me`, admin), uning ota-ona o'rni bo'shaydi (begona kalit SET NULL) va vasiylik so'rovlari hamda `GUARDIAN_REVIEW`
bildirishnomalari ham o'chadi. Boshqa bolalar va o'quvchi qatorlariga tegilmaydi.

## 10. Xavfsizlik

| Xavf | Chora |
|---|---|
| Kodni tanlab topish (10^6) | bola: 5/15 daq. (profil) + 60/15 daq. (IP) xato; ota-ona: 5/30 daq. (foydalanuvchi) + 30 (IP), ikkala tur kod uchun umumiy; hisob "tekshir -> bajar -> hisobla" ketma-ket (parallel so'rov aylanib o'ta olmaydi); bola endpointida qo'shimcha 30 so'rov/10 daq. (bola bo'yicha); kod 24 soat; bola kodi faqat `UNDER_REVIEW` beradi |
| Begona ota-onaning vasiy bo'lib olishi | 6 raqamli kod vasiylik bermaydi: faqat o'zi vasiy yoki maktab yozuvining haqiqiy telefoni mos ota-ona ulanadi, qolganlari — xodim tasdig'i (`GUARDIAN`); tasdiqlanmaguncha vasiy yozuvi YO'Q, shuning uchun barcha ota-ona yo'llari (davomat, xabarlar, to'lov, olib ketish, erta ketish, PUT) inkor qiladi; `userId`-only so'rovlarga qo'shimcha `linkStatus: LINKED` filtri; rad etilgan ota-ona shu kodni qayta kirita olmaydi |
| Sabab bo'yicha enumeratsiya | noto'g'ri / muddati o'tgan / yopilgan / band kod — bir xil `CODE_INVALID` (bola) yoki `INVITE_INVALID` (ota-ona); tasdiqlangan bolaga har qanday kod uchun bir xil `ALREADY_ENROLLED` |
| PII | nomlar faqat `CONFIRMED`da; kutayotgan ota-onaga o'quvchi ma'lumoti yo'q; xodim ro'yxatida ota-ona telefoni faqat niqoblangan (oxirgi 4 raqam); bildirishnomada faqat `{studentName, className}`; auditda kod, bola ismi va telefon yo'q; bola izohi faqat xodim ro'yxatida |
| IDOR | har bir xodim amali `schoolId` + sinf doirasi bilan; bola faqat o'z `Child` yozuvi (token → `childUserId`); ota-ona faqat o'z farzandlari; so'rov id'si boshqa maktabda `404` |
| Poyga | `pg_advisory_xact_lock` (tartib: kod maydoni → bola → o'quvchi) + qisman unique indekslar (faol kod, o'quvchida bitta faol kod, bolada bitta kutayotgan o'rin / ochiq so'rov) |
| Eskirgan holat | tasdiqlash va uzish har qanday yo'l bilan bo'lsa ham kod yozuvlari / tuzatish so'rovlari tozalanadi (§6); ota-ona ishonchi jonli vasiylikdan olinadi; xodim qarori ko'rilgan bolaga bog'langan (§5) |

## 11. Qarorlar va ochiq savollar

Hal qilingan:

1. **Ota-ona o'rni** — 6 raqamli kod O'ZI vasiylik yoki tasdiqlangan bog'lanish bermaydi (§4, §5). Oldin bu ochiq xavf edi
   (kodni topgan begona ota-ona darhol vasiy bo'lardi); endi xodim tasdig'i yoki telefon mosligi shart.
2. **IP limiti** — bola kodi uchun IP bo'yicha 60 noto'g'ri urinish / 15 daq. (maktab NAT'i); bola profili bo'yicha 5 o'zgarmagan.

Qoldirilgan (hujjatlashtirilgan):

3. Bildirishnoma oluvchilari yozuv yaratilganda belgilanadi (§7). Sinf almashtirilganda yoki rol/ruxsat o'zgarganda mavjud
   `LINK_*` / `GUARDIAN_REVIEW` bildirishnomasi eski oluvchilarda qoladi (navbat sahifasi har doim joriy holatni ko'rsatadi).
   Direktorlar jadvaldagi ruxsatga ko'ra oddiy oluvchi (kontraktdagi "sinf rahbari + administrator" ro'yxatidan farqli).
4. Rad etilgan `REVIEW` / `GUARDIAN` da kod yopilgan bo'lsa (ikkala o'rin band bo'lgan) qayta ochilmaydi — yangi kod yaratiladi.
5. Tuzatish `OPEN` bo'lganda maktab ma'lumoti yopiladi, lekin: bolaning o'rganish natijalari maktab hisobotidagi sinfga
   (`LearningAttempt` snapshoti), maktab rejimi (qurilma cheklovlari) va neytral push'lar (matnsiz e'lon / uy vazifasi
   eslatmasi) o'zgarmaydi — ular maktab ma'lumotini bolaga ochmaydi.
6. Tasdiqlangan ota-ona uchun yaratilgan vasiy yozuvi ota-ona akkaunti o'chganda ham maktab yozuvi sifatida qoladi
   (`userId` bo'shaydi, ism / telefon qoladi — mavjud vasiy modeli bilan bir xil). Ota-ona aloqani uzib qayta kiritsa,
   telefoni qoldirilgan yozuvga mos kelsa o'sha yozuv qayta ulanadi, aks holda yana xodim tasdig'i kerak.
7. Urinish hisobi xotirada (bitta instance; qayta ishga tushganda nolga tushadi) — mavjud ota-ona limiti kabi.
8. Ota-ona kutayotgan so'rovni o'zi bekor qila olmaydi (`DELETE /links/:reviewId` yo'q) — faqat xodim hal qiladi. Xodim
   uchun `GET /school/students/:id/invite-code` da ota-ona o'rni kutayotgan so'rov uchun ham `USED` (alohida holat yo'q).
