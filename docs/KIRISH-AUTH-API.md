# Kirish (A01–A12), 1-qism — bola login/parol, sessiyalar, tiklash, profil (backend kontrakti)

Branch: `feat/kirish-auth` (origin/main `8a511d50`'dan). Migratsiya: **`20261109090000_kirish_auth`**
(faqat qo'shuvchi: 3 yangi enum; 2 yangi jadval — `child_credentials`, `child_recovery_requests`; `children.education_language`,
`users.created_via`, `user_sessions.{device_id, kind, revoked_reason, is_main}` — hammasi nullable yoki default'li).
Mavjud qatorlarga tegilmaydi (migratsiyada `UPDATE` / `DELETE` yo'q). Maktab kodi / taklif kodi / tuzatish (K2) bu hujjatga kirmaydi.

Manba kontrakt: `kirish-contract.md` (K1 bo'limi) + koordinator qo'shimchalari (`deviceRole`, oluvchilar qoidasi, IP limiti / shaffoflik push'i /
vaqtinchalik parol muddati qarorlari, `device.hostsControl`, `child.parentId`). Hamma yo'l `/api` prefiksi bilan.

## 0. Umumiy qoidalar

- **Xatolar:** `{ statusCode, code, message }` (+ ba'zilarida `reason` / `retryAfterSeconds`). DTO tekshiruvi (class-validator,
  `forbidNonWhitelisted`) xatosi — standart `400` (`message` massiv). Quyida to'liq kodlar jadvali (8-bo'lim).
- **Mavjudlik fosh bo'lmaydi.** Ommaviy yo'llar (`child-login`, `child-setup`, `child-recovery`, poll) login / bola / maktab bor-yo'qligini
  holat kodi, javob shakli, xato kodi, limit xatti-harakati, javob vaqti (tartibi) va poll'dagi `channel` bo'yicha ham ko'rsatmaydi.
- **Mavjud oqimlar o'zgarmadi:** oila kodi bilan juftlash (`POST /auth/child-pair`), qayta ulash QR'i (`repair-qr` / `repair-redeem`), `sid`siz
  tokenlar va ularning yangilanishi, ota-ona kirishi / sessiyalari / 2-qurilma limiti, 8 belgili vasiy kodlari, barcha joriy ota-ona va bola
  ilovasi oqimlari. Regressiya e2e bilan isbotlangan (`kirish-regression`). Yagona xulq o'zgarishi: `POST /auth/device-link/create` endi faqat `PARENT` (3.5).
- **Qarorlar:** D1 kirish maʼlumotini ota-ona yoki maktab beradi (maktab — faqat `SchoolStudent.childId` bog'langan o'quvchi uchun, ota-ona
  roziligisiz hisob ochilmaydi); D2 nazorat ota-ona juftlagan qurilmada qoladi, boshqa qurilmadagi login — faqat akkaunt kirishi; D4 mavjud juftlangan
  bolalar tizimda qoladi; D7 tiklash (reset) boshqa qurilmalarni chiqaradi (`signOutDevices` standart `true`).
- **Maxfiy javoblar** (`child-login`, `child-setup`, vaqtinchalik parol, tiklash so'rovi / poll) `Cache-Control: no-store` bilan.
- `...At` maydonlari — ISO-8601 (UTC). Login har doim kichik harfda saqlanadi; kirishda bo'shliqlar kesiladi va harf registri farqsiz.
- **429 ikki xil, ikkalasi ham** `{ "statusCode": 429, "code": "LOCKED" | "RATE_LIMITED", "message": "…", "retryAfterSeconds": <son> }`:
  `LOCKED` — shu LOGIN bloklangan (15 daqiqada 5 xato); `RATE_LIMITED` — IP / foydalanuvchi limiti.

## 1. Ma'lumotlar modeli

`child_credentials` (bolaga bitta; `child_id` PK, FK `children` ON DELETE CASCADE):

| Ustun | Izoh |
|---|---|
| `login` (UNIQUE) | `^[a-z][a-z0-9._]{3,23}$` |
| `password_hash` | bcrypt (12 raund). Vaqtinchalik / bola paroli hech qayerda ochiq saqlanmaydi |
| `must_change_password` (default `true`) | vaqtinchalik parol — birinchi kirishda almashtiriladi; **14 kun** amal qiladi (`issued_at` + 14 kun) |
| `failed_logins`, `failed_window_started_at`, `locked_until` | 15 daqiqada 5 xato -> 15 daqiqa blok (qo'shimcha: oyna boshi shartnomadagi 5 ustundan tashqari) |
| `issued_by` (`PARENT` \| `SCHOOL`), `issued_by_user_id?`, `issued_by_staff_id?`, `issued_at` | oxirgi bergan / tiklagan |
| `password_changed_at?`, `last_login_at?`, `created_at`, `updated_at` | |

`child_recovery_requests`: `id`, `child_id?` (NULL — mavjud bo'lmagan login uchun "o'lik" so'rov), `channel` (`PARENT` \| `SCHOOL`; **samarali** kanal — yetkazish
va ro'yxatlar shu bo'yicha), `requested_channel` (bola **so'ragan** kanal; poll shuni qaytaradi), `status` (`RECEIVED` \| `RESTORED` \| `REJECTED`), `poll_token_hash`
(SHA-256; token o'zi saqlanmaydi), `created_at`, `restored_at?`, `signed_out_at?`, `rejected_at?`.

`user_sessions`: `device_id` (ilova o'rnatish id'si), `kind` (`'LOGIN'` — login bilan kirish; NULL — eski kirishlar), `revoked_reason`,
`is_main`. `users.created_via`: NULL — eski juftlash (oila kodi / QR), `'LOGIN'` — login bilan yaratilgan, `'RECOVERED'` — eski juftlash
foydalanuvchisi, lekin juftlangan qurilma tiklashda chiqarilgan. `children.education_language` (nullable).

**Parol siyosati (bola tanlagan):** 8–64 belgi (va UTF-8 bo'yicha ko'pi bilan 72 bayt — bcrypt kesib tashlamasin), kamida 1 harf va 1 raqam,
loginning o'zi emas (registrsiz), kichik taqiqlangan ro'yxatda (`password1`, `qwerty123`, `parvoz123` …) yo'q. Almashtirishda joriy / vaqtinchalik
parolning o'zi ham rad etiladi. Buzilsa — `400 { code: 'WEAK_PASSWORD', reason }`, `reason` ∈ `TOO_SHORT | TOO_LONG | NEEDS_LETTER |
NEEDS_DIGIT | SAME_AS_LOGIN | TOO_COMMON | SAME_AS_CURRENT`.

## 2. Kirish maʼlumotlarini berish / qayta tiklash

### Ota-ona: `GET /api/children/:childId/credentials` (rol `PARENT`, faqat o'z bolasi)

```json
{ "login": "aziza.k24", "issuedBy": "PARENT", "issuedAt": "2026-11-09T09:00:00.000Z", "mustChangePassword": true,
  "temporaryPasswordExpiresAt": "2026-11-23T09:00:00.000Z", "lastLoginAt": null }
```
Berilmagan bo'lsa tana `null` (`200`, matn `null`). Parol xeshi va parol hech qachon qaytmaydi. **`temporaryPasswordExpiresAt`** (YANGI) — `issuedAt` + 14 kun,
faqat `mustChangePassword = true` paytida; bola o'z parolini o'rnatgach `null`.

### Ota-ona: `POST /api/children/:childId/credentials` → `201`

Tana (hammasi ixtiyoriy): `{ "login"?: string, "signOutDevices"?: boolean }`.

```json
{ "login": "aziza.k24", "temporaryPassword": "k7m2qx9d", "issuedAt": "2026-11-09T09:00:00.000Z", "temporaryPasswordExpiresAt": "2026-11-23T09:00:00.000Z" }
```
**Vaqtinchalik parol javobda FAQAT BIR MARTA** (8 belgi, `abcdefghjkmnpqrstuvwxyz23456789`, kripto-tasodif). Bazada faqat bcrypt xeshi; audit, log, push
va xodim bildirishnomasiga yozilmaydi (e2e butun bazani qidirib isbotlaydi). **`temporaryPasswordExpiresAt`** (YANGI, qo'shimcha maydon) — `issuedAt` + 14 kun; mijoz shuni
ko'rsatadi ("14 kun ichida kiring"). Throttle: ota-ona boshiga 10 daqiqada 20 ta (login izlash/sinab ko'rishga qarshi) → `429 RATE_LIMITED`.

- **Birinchi berish:** `login` berilgan, yaroqli (`^[a-z][a-z0-9._]{3,23}$`, registrsiz) va bo'sh bo'lsa — o'sha; yaroqsiz bo'lsa — taklif qilingani;
  yaroqli, lekin band bo'lsa — `409 LOGIN_TAKEN`. Taklif: ism lotinga o'giriladi (kirill, `oʻ`/`gʻ`, diakritiklar) + `"."` + familiya bosh harfi + 2 raqam
  (`aziza.k24`; familiya yo'q bo'lsa `aziza.24`), band bo'lsa boshqa raqamlar, oxirgi zaxira `parvoz` + 4 raqam. Ota-onada bola ismining birinchi so'zi ism,
  oxirgisi familiya; maktabda `SchoolStudent.firstName` / `lastName`. Birinchi berish hech kimni chiqarmaydi.
- **Qayta tiklash (credential allaqachon bor):** `login` o'zgarmaydi (tanadagisi e'tiborsiz); yangi vaqtinchalik parol, `mustChangePassword = true`,
  `failedLogins = 0`, blok olib tashlanadi, `issuedBy` / `issuedAt` yangilanadi (**14 kunlik muddat qaytadan boshlanadi**). Bolaning ochiq tiklash so'rovlari `RESTORED` bo'ladi.
  `signOutDevices` (standart `true`):
  1. bola foydalanuvchisining BARCHA sessiyalari `RECOVERED` sababi bilan yopiladi;
  2. `tokenVersion++` (eski, `sid`siz juftlangan qurilmaning yangilash tokeni ham yaroqsiz);
  3. FCM tokenlari o'chadi (chiqarilgan / yo'qolgan telefonga push ketmasin);
  4. WebSocket: `child:unpaired` `{ childId, reason: 'RECOVERED', at }` (eski bola ilovasi mahalliy uzadi) VA `session:closed` `{ sessionIds, reason: 'RECOVERED' }`;
     keyin (~1,5 s) bolaning **ochiq socketlari uziladi** (qayta ulanishda token tekshiriladi — 4.3);
  5. juftlangan qurilma asosiylikdan chiqadi (`users.created_via = 'RECOVERED'`) — keyingi kirgan qurilma `MAIN` bo'ladi (3.4);
  6. so'rovlar `RESTORED` va `signedOutAt` to'ladi.
  `signOutDevices: false` — hech qaysi sessiya / token / push / asosiy belgi o'zgarmaydi (socketlar ham uzilmaydi).
- Parallel berish / tiklash bola qatori bo'yicha navbatga turadi; loginlar yagonaligi global advisory lock bilan kafolatlanadi.
- **Audit** (`audit_logs`, parol va login YO'Q): `CHILD_CREDENTIAL_ISSUE` / `CHILD_CREDENTIAL_RESET`, `data`: `{ signedOutDevices, closedSessions, resolvedRequests }`.

Xatolar: boshqa ota-ona bolasi `403 FORBIDDEN`; noma'lum bola `404 CHILD_NOT_FOUND`; bola tokeni `403`; tokensiz `401`; throttle `429 RATE_LIMITED`.

### Maktab: `GET/POST /api/school/students/:studentId/credentials`

Bir xil shakllar (`temporaryPasswordExpiresAt` ham). Ruxsat **`students.manage`** (DIRECTOR, ADMIN; sinf doirali rolga berilsa — faqat o'z sinfi, doiradan tashqari `403`). Boshqa maktab o'quvchisi /
noma'lum id → `404`. O'quvchi Parvoz bola profiliga bog'lanmagan (`childId` yo'q) → `409 { code: 'NOT_LINKED' }` (GET va POST). Arxivlangan o'quvchiga berish →
`409 STUDENT_ARCHIVED` (o'qish mumkin). `issuedBy = SCHOOL`, `issued_by_staff_id` = xodim. Maktab auditi (modul `STUDENTS`, parolsiz va loginsiz):
`student.credential.issue` / `student.credential.reset`.

**Ota-onaga neytral push (shaffoflik, YANGI):** maktab berganda / tiklaganda ota-onaga (fonda, javobni kechiktirmaydi) push ketadi:

```json
{ "title": "Parvoz", "body": "Maktab farzandingizga kirish maʼlumotlarini berdi", "data": { "type": "CHILD_CREDENTIAL_SCHOOL", "childId": "…" } }
```
Tiklashda `body`: «Maktab farzandingizning kirish maʼlumotlarini yangiladi». Ota-ona tilida (uz / ru / en: «Школа выдала вашему ребёнку данные для входа» / «Школа обновила данные для входа вашего ребёнка»;
«The school gave your child sign-in details» / «The school renewed your child’s sign-in details»). **Login, parol va bola ismi pushda YO'Q** (faqat `type` va `childId`). Faqat ota-onaning FCM tokeni bo'lsa
yuboriladi; push xatosi so'rovni buzmaydi; rad etilgan so'rov (403 / 409) hech narsa yubormaydi; ota-onaning o'z berishi / tiklashi bu pushni yubormaydi.

## 3. Bola kirishi

### 3.1 `POST /api/auth/child-login` (ommaviy) → `200`

```json
{ "login": "aziza.k24", "password": "k7m2qx9d", "device": { "id": "install-uuid", "model": "Redmi Note 12S", "platform": "android", "hostsControl": true } }
```
`device.id` 1–64 belgi, `model` ≤ 60 (ixtiyoriy), `platform` ∈ `android | ios`, **`hostsControl`** (YANGI, ixtiyoriy `boolean`, standart `true`; 3.4). Boshqa maydon yoki noto'g'ri tur
(`"false"`, `0`, obyekt) → `400`; `null` yuborilmagandek hisoblanadi.

Vaqtinchalik parol bilan (`mustChangePassword`) — **sessiya yo'q**:
```json
{ "status": "SETUP_REQUIRED", "setupToken": "<jwt>", "child": { "id": "…", "name": "Aziza Karimova" } }
```
Aks holda:
```json
{ "status": "OK", "accessToken": "…", "refreshToken": "…", "sessionId": "…", "deviceRole": "MAIN",
  "child": { "id": "…", "name": "Aziza Karimova", "parentId": "…" }, "user": { "id": "…" } }
```
**`child.parentId`** (YANGI) faqat `OK` javobda (ilova ikkinchi so'rovsiz biladi; bola tokeni `GET /children/:id` bilan uni baribir o'qiy oladi). `SETUP_REQUIRED` da `child` — faqat `{ id, name }`.

- Bola foydalanuvchisi: `Child.childUserId` faol bo'lsa o'sha (juftlangan qurilma ishlashda davom etadi), aks holda yangisi (`created_via = 'LOGIN'`) yaratilib
  `childUserId` ga yoziladi. `pairedAt` / `isConnected` tegilmaydi (login — akkaunt kirishi, juftlash emas).
- Tokenlarda `sid` bor; yangilash mavjud `POST /auth/refresh` bilan (rotatsiya) — boshqa sessiyalar bilan bir xil.
- Sessiyaga bola IP'si / User-Agent / geo SAQLANMAYDI (ma'lumot minimallashtirish). Audit: `AUTH_CHILD_LOGIN` (IP / User-Agent yo'q).
- `401 INVALID_CREDENTIALS` — noto'g'ri login VA noto'g'ri parol (hamda yaroqsiz formatdagi login) uchun **bir xil javob**; mavjud bo'lmagan login uchun ham bcrypt
  tekshiruvi va xuddi shu DB ishi bajariladi (soxta xesh, tasodifiy id bilan yozuv urinishi), vaqt farqi yo'q. Blok boshlanganda bitta audit yozuvi: `AUTH_CHILD_LOGIN_LOCKED` (`{ lockedSeconds }`; login va IP yo'q).
- **Vaqtinchalik parol muddati (YANGI):** to'g'ri, lekin 14 kunlik muddati o'tgan vaqtinchalik parol →
  `401 { "statusCode": 401, "code": "TEMP_PASSWORD_EXPIRED", "message": "Temporary password has expired" }` — **setupToken YO'Q**, sessiya yo'q, blok hisobi o'zgarmaydi. Noto'g'ri parol muddatdan keyin ham
  `INVALID_CREDENTIALS` bo'lib qoladi va blokka sanaladi (muddat parolni bilmaydiganga fosh bo'lmaydi). Chiqish yo'li: ota-ona / maktab qayta tiklaydi (yangi 14 kun) yoki bola tiklash so'rovi yuboradi (5-bo'lim).
  O'z paroliga muddat tegishli emas.
- **Blok:** bir login uchun 15 daqiqada 5 xato parol → `lockedUntil = now + 15 daqiqa`. **5-xatoning o'zi allaqachon `429`**, blok davomida to'g'ri parol ham
  `429` (parol tekshirilmaydi, urinish sanalmaydi):
  `{ "statusCode": 429, "code": "LOCKED", "message": "Too many failed attempts", "retryAfterSeconds": 900 }`. Oyna birinchi xatodan 15 daqiqa; muvaffaqiyatli kirish /
  tiklash / parol o'rnatish hisobni tozalaydi. Hisob qator qulfi bilan yuritiladi: parol tekshirilgandan keyin blok va xesh qator qulfi ostida **qayta** tekshiriladi (parallel noto'g'ri urinishlar blokdan oshib ketmaydi;
  sessiya ochilayotganda ham tiklash / blok kirib qolsa rad etiladi).
  **Mavjud bo'lmagan loginlar uchun ham xuddi shu qoida xotirada** ("soya" blok, 10 000 yozuv bilan cheklangan, qayta ishga tushganda tozalanadi) — "5 urinishdan
  keyin 429" xatti-harakati login mavjudligini fosh qilmaydi.
- **IP limiti (O'ZGARDI — faqat XATOLAR sanaladi):** bitta IP'dan 10 daqiqada **30 ta xato urinish** (`401 INVALID_CREDENTIALS` va `429 LOCKED` javoblari). Muvaffaqiyatli kirish (`OK`, `SETUP_REQUIRED`) va `TEMP_PASSWORD_EXPIRED`
  limitni YEMAYDI — maktab Wi-Fi'sida (NAT) bir vaqtda kirayotgan ko'p bola bir-biriga xalaqit bermaydi. Limitga yetgan IP: `429 { statusCode, code: 'RATE_LIMITED', message: 'Too many requests', retryAfterSeconds }`
  (parol tekshirilmaydi — bcrypt ishlamaydi; oyna siljuvchi, `retryAfterSeconds` ≤ 600). Parallel "portlash" (xatolar hali yozilmagan) bitta IP'dan bir vaqtdagi 50 ta urinish bilan cheklanadi: ortiqchasi darhol
  `429 RATE_LIMITED` (`retryAfterSeconds: 1`). `child-login` va `child-setup` hisoblari alohida.

### 3.2 `POST /api/auth/child-setup` (ommaviy) → `200` (OK tanasi yuqoridagi bilan bir xil: `deviceRole`, `child: { id, name, parentId }`)

```json
{ "setupToken": "<jwt>", "newPassword": "Kitob2026", "device": { "id": "install-uuid", "model": "Redmi", "platform": "android", "hostsControl": true } }
```
Parol o'rnatiladi (`mustChangePassword = false`, `passwordChangedAt`), keyin sessiya ochiladi. Siyosat buzilsa `400 WEAK_PASSWORD` (token **sarflanmaydi**).
**setupToken:** 15 daqiqa, **bir martalik**, `purpose: 'child-setup'`. Xavfsizlik:
- access / refresh tokenidan butunlay ajratilgan: alohida imzo kaliti (`JWT_ACCESS_SECRET`dan maqsadli HMAC bilan hosila) va alohida `aud` (`farzandim-child-setup`) — Bearer,
  WebSocket yoki refresh sifatida o'tmaydi; access / refresh token ham setupToken sifatida o'tmaydi;
- bir martalik: tokenda joriy parol xeshining kalitli barmoq izi (`fp`); parol o'rnatilgach (yoki ota-ona qayta tiklasa) xesh o'zgaradi va eski token yaroqsiz bo'ladi.
  Parallel ikki urinishda shartli `UPDATE` (xesh bo'yicha compare-and-swap) tufayli faqat bittasi yutadi. Alohida jti jadvali kerak emas;
- boshqa bolaning tokeni bilan o'rnatib bo'lmaydi (`cid`).

Yaroqsiz / muddati o'tgan / ishlatilgan token → `401 SETUP_TOKEN_INVALID`. Token berilgandan keyin (15 daqiqalik oynada) vaqtinchalik parolning 14 kunlik muddati tugagan bo'lsa → `401 TEMP_PASSWORD_EXPIRED`
(token 15 daqiqalik, lekin 14 kunni uzaytirmaydi). **IP limiti:** faqat `SETUP_TOKEN_INVALID` javoblari sanaladi (10 daqiqada 30 ta → `429 RATE_LIMITED`); zaif parol (`400`) va muvaffaqiyatli o'rnatish sanalmaydi.

### 3.3 `POST /api/auth/child/password` (rol `CHILD`) → `204`

`{ "currentPassword": "…", "newPassword": "…" }`. Joriy parol xato → `400 WRONG_PASSWORD` va u blok hisobiga qo'shiladi (o'g'irlangan access token bilan parolni
topishga qarshi; 5-xato `429 LOCKED`). Yangi parol siyosatdan o'tmasa `400 WEAK_PASSWORD`. Muvaffaqiyatda foydalanuvchining **boshqa LOGIN sessiyalari** `SIGNED_OUT` bilan yopiladi
(+ `session:closed`); joriy sessiya (va sid'siz juftlangan qurilma) qoladi. Oila kodi bilan juftlangan, login berilmagan bola → `404 NO_CREDENTIAL`. Audit: `AUTH_CHILD_PASSWORD_CHANGE`.
**Himoya (YANGI):** foydalanuvchi boshiga 15 daqiqada 10 urinish → `429 RATE_LIMITED` (har urinish bcrypt); parol tekshirilgandan keyin blok va xesh qator qulfi ostida qayta tekshiriladi —
parallel taxminlar blokni aylanib o'tolmaydi: blok qo'yilgan bo'lsa `429 LOCKED`, parol tiklash tufayli o'zgargan bo'lsa `409 PASSWORD_CHANGED`.

### 3.4 Qurilma roli (`deviceRole`: `MAIN` | `SECONDARY`) va `device.hostsControl`

`child-login` (OK) va `child-setup` javoblarida. **MAIN** — nazorat shu qurilmada ishlaydi (D2); **SECONDARY** — faqat akkaunt kirishi. Rol sessiya ochilganda **bir marta** belgilanadi,
yangilashda o'zgarmaydi. Sessiya MAIN bo'ladi, agar bolada hozirgi asosiy qurilma **yo'q** bo'lsa. Asosiy qurilma bor, agar:
- (a) `Child.childUserId` foydalanuvchisi faol va eski juftlash (oila kodi / QR) bilan yaratilgan (`users.created_via IS NULL`; barcha eski qatorlar) — `sid`siz juftlangan qurilma asosiy; yoki
- (b) yopilmagan LOGIN sessiyasi `is_main = true`.

Qoidalar: birinchi login (juftlangan qurilma yo'q) → MAIN, ikkinchisi → SECONDARY; juftlangan qurilma bor → har qanday login SECONDARY; asosiy sessiya yopilsa (chiqish, boshqa qurilmadan
tugatish, 4-kirishda eng eskisining siqib chiqarilishi — asosiy ham eng eski bo'lishi mumkin) rol bo'shaydi va keyingi kirgan qurilma MAIN bo'ladi; xuddi shu qurilmaning qayta kirishi eski sessiyasini
almashtiradi (asosiy bo'lsa MAIN qoladi); **`signOutDevices` bilan tiklash** asosiy belgini tozalaydi (juftlangan qurilma ham: `created_via = 'RECOVERED'`) — keyingi kirish MAIN; `signOutDevices: false` hech narsani
o'zgartirmaydi; QR bilan qayta ulangan yangi juftlangan qurilma asosiy bo'ladi (keyingi loginlar SECONDARY). Parallel kirishlarda aniq bittasi MAIN (foydalanuvchi qatori qulflanadi).
Juftlash oqimlari (oila kodi / QR) o'zgarmadi.

**`device.hostsControl` (YANGI, ixtiyoriy, standart `true`):** mijoz `false` yuboradi, agar bu qurilma allaqachon BOSHQA bolaning ota-ona nazoratini yuritayotgan bo'lsa (shu bolaning nazoratini bajara olmaydi).
`false` bo'lsa **YANGI sessiya hech qachon MAIN bo'lmaydi** (SECONDARY) — bolada asosiy qurilma bo'lmasa ham; asosiy keyingi `hostsControl: true` / yuborilmagan kirishga qoladi. **Istisno:** shu qurilmadagi
bu foydalanuvchining joriy ASOSIY sessiyasini almashtiradigan qayta kirish (egasi qayta kirishi) `hostsControl: false` bilan ham MAIN qoladi — ega pasaytirilmaydi. Mavjud asosiy (juftlangan yoki login) sessiya hech qachon
pasaytirilmaydi va ikkinchi MAIN yaratilmaydi. Bayroq saqlanmaydi (faqat rolni belgilaydi). `child-login` ham, `child-setup` ham qabul qiladi.

### 3.5 `POST /api/auth/device-link/create` endi faqat `PARENT`

Oldin har qanday rol chaqira olardi: bola foydalanuvchisi shu yo'l bilan `kind`siz sessiya yarata olardi — u 3 ta sessiya chegarasi, `GET /auth/child/devices` ro'yxati va parol almashtirishda yopilishni chetlab o'tardi.
Endi bola tokeni `403`. Ota-ona (2-qurilma QR'i) o'zgarmagan; `device-link/redeem` o'zgarmagan.

## 4. Sessiyalar va "sessiya yopildi" (A12)

### `GET /api/auth/child/devices` (rol `CHILD`)

```json
[
  { "sessionId": "…", "model": "Redmi Note 12S", "platform": "android", "lastSeenAt": "2026-11-09T09:05:00.000Z", "current": true,  "paired": false, "main": true },
  { "sessionId": null, "model": "Samsung A52", "platform": "android", "lastSeenAt": "2026-11-01T10:00:00.000Z", "current": false, "paired": true,  "main": true }
]
```
Faqat yopilmagan LOGIN sessiyalari (`lastSeenAt` kamayish tartibida) + (bor bo'lsa) ota-ona juftlagan qurilma (`sessionId: null`, `paired: true`, `main: true`; `current` — so'rov `sid`siz tokendan).
Juftlangan qurilma tiklashda chiqarilgan bo'lsa ro'yxatda yo'q. Sessiya elementlarida `paired: false` (kontraktdagi maydonlarga qo'shimcha).

### Yopish sabablari (`user_sessions.revoked_reason`)

| Sabab | Qachon |
|---|---|
| `RECOVERED` | ota-ona / maktab `signOutDevices` bilan tikladi |
| `SIGNED_IN_ELSEWHERE` | 4-LOGIN sessiyasi ochildi — eng eskisi yopildi (ota-onada: 2-qurilma QR havolasi egasidan boshqasini chiqardi) |
| `SIGNED_OUT` | `POST /auth/logout`, `DELETE /auth/sessions/:id`, `DELETE /auth/sessions/others`, bola parolini almashtirdi (boshqa sessiyalar), xuddi shu qurilmaning qayta kirishi (eski sessiya) |
| `PERMISSIONS_CHANGED` | ota-ona qurilmani almashtirdi (qayta ulash QR'i, qurilma almashtirish so'rovini tasdiqlash) — eski bola foydalanuvchisining sessiyalari |

Har yopishda sabab saqlanadi va bola foydalanuvchi xonasiga WebSocket: `session:closed` `{ "sessionIds": ["…"], "reason": "SIGNED_IN_ELSEWHERE" }`. Mijoz o'z `sid`ini `sessionIds` bilan solishtiradi.
Tiklashda ro'yxat bo'sh bo'lishi mumkin (faqat `sid`siz juftlangan qurilma yopilgan) — shunda `child:unpaired` ham keladi.

### `POST /api/auth/refresh`: yopilgan sessiya

`sid`li yangilash tokeni yopilgan (yoki o'chirilgan) sessiyaga tegishli bo'lsa:
`401 { "statusCode": 401, "code": "SESSION_REVOKED", "reason": "RECOVERED" | "SIGNED_IN_ELSEWHERE" | "SIGNED_OUT" | "PERMISSIONS_CHANGED" | null, "message": "Session revoked" }`
(`reason: null` — bu relizgacha yopilgan sessiya). Sessiya tekshiruvi `tokenVersion` / faollik tekshiruvidan **oldin** (tiklashda ikkalasi ham o'zgaradi, ilova esa sababni ko'rsatishi kerak).
`message` matni avvalgidek ("Session revoked") — eski mijozlar faqat `401` ga qaraydi. `sid`siz tokenlar uchun javoblar o'zgarmagan.

**Eslatma (qaror: o'zgarmaydi):** access token (15 daqiqa) yopilgan sessiyadan keyin muddati tugaguncha stateless tekshiruvdan o'tadi (butun tizimdagi mavjud xatti-harakat); yangilash darhol bloklanadi,
WebSocket xabari bir zumda keladi va WebSocket ulanishi endi yopilgan sessiyaga berilmaydi (quyida).

### WebSocket (YANGI qattiqlashtirish)

- **Ulanish (handshake):** yopilgan / o'chirilgan / boshqa foydalanuvchiga tegishli `sid`li token, `tokenVersion`i eskirgan token va nofaol foydalanuvchi uziladi (xonaga qo'shilmaydi). `sid`siz (eski juftlangan) token faqat `tokenVersion`
  bilan tekshiriladi. Tekshiruv bazaga ≤ 2 ta indeksli so'rov; baza xatosi ulanishni to'smaydi (JWT imzosi yetarli, avvalgidek).
- **Uzish:** tiklash `signOutDevices` bilan bo'lsa, bolaning barcha ochiq socketlari `session:closed` / `child:unpaired` dan ~1,5 s keyin uziladi — chiqarilgan qurilma tirik socket orqali hodisalarni olishda davom etmaydi.

### Boshqa qoidalar

- Bir foydalanuvchida ko'pi bilan **3 ta** faol LOGIN sessiyasi; 4-chisida eng eskisi (`createdAt`) `SIGNED_IN_ELSEWHERE` bilan yopiladi. Parallel kirishlar foydalanuvchi qatori qulfi bilan navbatga turadi.
- Ota-ona sessiyalari va 2-qurilma limiti sanalmaydi (alohida: `kind IS NULL`).
- `POST /auth/logout` LOGIN sessiya uchun faqat shu sessiyani yopadi (`SIGNED_OUT`).

## 5. Tiklash so'rovlari (A03/A04)

### `POST /api/auth/child-recovery` (ommaviy) → DOIM `202`

```json
{ "login": "aziza.k24", "channel": "PARENT" }
```
```json
{ "requestId": "…", "pollToken": "<43 belgi base64url>" }
```
Login mavjud bo'lmasa (yoki yaroqsiz formatda) — `childId = NULL` "o'lik" so'rov yaratiladi va hech qachon yechilmaydi. Javob shakli, holat kodi, sarlavhalar bir xil; ta'sirlar **javobdan keyin fonda**
bajariladi (FCM sekin bo'lsa ham mavjud / mavjud bo'lmagan login vaqti ajralmaydi). `pollToken` faqat SHA-256 xesh sifatida saqlanadi. Vaqtinchalik paroli muddati o'tgan bola ham shu yo'l bilan yangisini so'raydi.

Ta'sirlar (mavjud login):
- **PARENT** → ota-onaga neytral push: `{ title: 'Parvoz', body: 'Farzandingiz kirish maʼlumotlarini tiklashni soʻradi' (ota-ona tilida; bola ismi yo'q), data: { type: 'CHILD_RECOVERY_REQUEST', childId } }`.
- **SCHOOL** → faqat bola faol maktab o'quvchisiga bog'langan bo'lsa (arxivlanmagan, maktab `ACTIVE`): `school_staff_notifications` (`id = child-recovery:<requestId>`, `kind = CHILD_RECOVERY_REQUEST`,
  `params = { studentName, className }` — boshqa hech narsa, `href = '/students/view?id=<studentId>&tab=access'`). **Oluvchilar — faqat ish qila oladiganlar:** o'quvchining maktabidagi FAOL xodimlardan `students.manage` ruxsatiga ega va doirasi shu o'quvchini
  qamraganlar. Hozirgi rollar jadvalida bular DIRECTOR va ADMIN (butun maktab doirasi); sinf rahbari (HOMEROOM) — **faqat unga `students.manage` berilgan bo'lsa va o'z sinfi uchun**; sinfsiz o'quvchini faqat butun maktab
  doirasidagi rollar qamraydi. Rol nomlari qattiq yozilmagan: oluvchilar rollar jadvalidan (`SCHOOL_ROLES`, `roleHas` + doira) aniqlanadi (`school/common/staff-recipients.ts`). Hech kim mos kelmasa — direktor(lar)ga
  (`roles = ['DIRECTOR']`, `staffIds = []`). Oluvchilar `staffIds`ga, ularning rollari `roles`ga yoziladi (lenta ikkala shartni ham tekshiradi), `classIds = [classId]` (sinfsiz bo'lsa `[]`).
  Bola maktabga bog'lanmagan bo'lsa — **ota-onaga tushadi** (so'rovning `channel`i `PARENT` bo'ladi; lekin poll bola so'ragan kanalni qaytaradi — pastga qarang).
- Audit `AUTH_CHILD_RECOVERY_REQUEST` (login, IP, User-Agent yo'q).
- Bir bola uchun sutkada 3 tadan ortiq so'rov **bildirishnoma yubormaydi** (javob yana `202`; qayta ishga tushganda ham saqlanadigan chegara — bazadan sanaladi).

**Limitlar:** bitta login MATNI uchun sutkada 3 (har xil IP, registr / bo'shliq farqsiz; login mavjudmi yoki yo'qligidan qat'i nazar), bitta IP'dan sutkada **30** (O'ZGARDI: 10 edi; maktab Wi-Fi'si) →
`429 { statusCode, code: 'RATE_LIMITED', message, retryAfterSeconds }`. Limitlar xotirada (qayta ishga tushganda nolga tushadi; bolaga ta'sir DB asosidagi 3/sutka bilan baribir cheklangan).

### `GET /api/auth/child-recovery/:requestId?token=<pollToken>` (ommaviy)

```json
{ "status": "RECEIVED", "channel": "PARENT", "createdAt": "2026-11-09T09:00:00.000Z", "restoredAt": null, "signedOutAt": null }
```
`status`: `RECEIVED` → `RESTORED` (kredensial qayta tiklandi: `restoredAt`; `signedOutAt` — shu tiklash qurilmalarni chiqargan bo'lsa) yoki `REJECTED`.
**`channel` — bola SO'RAGAN kanal** (`requested_channel`), samarali emas (O'ZGARDI): `SCHOOL` so'ragan bola maktabga bog'lanmagan bo'lsa so'rov ota-onaga yo'naltiriladi, lekin poll baribir `SCHOOL` qaytaradi
(aks holda `PARENT` javobi login mavjudligini fosh qilardi). Noto'g'ri id / token / token yo'q — bir xil
`404 { code: 'NOT_FOUND', message: 'Request not found' }` (vaqt bo'yicha xavfsiz solishtirish). "O'lik" so'rov abadiy `RECEIVED`. 30 kundan eski so'rovlar (va xodim bildirishnomalari) kunlik cron bilan o'chadi.

### Ota-ona

- `GET /api/children/:childId/recovery-requests` → ochiq (`RECEIVED`) va **ota-onaga yuborilgan** (samarali kanal `PARENT`) so'rovlar, yangisi birinchi: `[{ "id", "channel": "PARENT", "status": "RECEIVED", "createdAt" }]`.
  Ota-ona **maktab kanalidagi so'rovlarni ko'rmaydi** (qaror).
- `POST /api/children/:childId/recovery-requests/:requestId/reject` → `200` va `REJECTED` ko'rinishi `{ id, channel, status: 'REJECTED', createdAt }`. Allaqachon yechilgan → `409 ALREADY_RESOLVED`; maktab kanalidagi /
  boshqa bolaning / noma'lum → `404 REQUEST_NOT_FOUND`. Boshqa ota-ona `403`. Audit `CHILD_RECOVERY_REJECT` (`{ requestId }`).
- Reset: 2-bo'limdagi `POST …/credentials` (so'rovlarni `RESTORED` qiladi).

### Maktab

- `GET /api/school/students/:id` (o'quvchi kartasi) — `recoveryRequests: [{ id, channel: 'SCHOOL', status: 'RECEIVED', createdAt }]` (ochiq maktab so'rovlari). Faqat javob bera oladigan xodimga (`students.manage`)
  ko'rsatiladi; boshqa rollar (sinf rahbari ruxsatsiz, psixolog …) uchun `[]`.
- `POST /api/school/students/:studentId/recovery-requests/:requestId/reject` — `students.manage`, 2-bo'lim qoidalari; javob `REJECTED` ko'rinishi; xodim bildirishnomasi olib tashlanadi; audit `student.recovery.reject`.
- Reset qilish — `POST /api/school/students/:studentId/credentials` (so'rovni `RESTORED` qiladi va bildirishnomani olib tashlaydi).
- Bildirishnomalar lentasi (`GET /api/school/notifications/feed`): `kind: 'CHILD_RECOVERY_REQUEST'`, `tone: 'warning'`, `params: { studentName, className }`, `subject: null`,
  **`href: '/students/view?id=<studentId>&tab=access'`** (YANGI; oldin `null`). `href` panelga nisbatan yo'l — boshqa lenta turlari kabi (`/care/requests/view?id=…`, `/attendance/early-exit`) `/school` prefiksisiz;
  `<studentId>` — `SchoolStudent.id`. Panel aynan shu o'quvchi kartasining «Kirish» bo'limini ochadi (bir xil ismli o'quvchilar adashmaydi; `/students?search=<ism>` kerak emas).
  Ko'rinadi: faqat yuqoridagi oluvchilarga (hozir DIRECTOR va ADMIN; sinf rahbariga `students.manage` berilsa — o'z sinfi uchun). DUTY / TEACHER / PSYCHOLOGIST, ruxsatsiz sinf rahbari va boshqa maktab xodimlari — yo'q.

## 6. Profil (A06)

- `PUT /api/children/me` (rol `CHILD`) endi `gender` (`male | female`) va `educationLanguage` (`uz | ru | kaa`) ni ham qabul qiladi. Boshqa qiymat va `null` → `400` (hech narsa o'zgarmaydi);
  berilmagan maydonlar o'zgarmaydi. Javob — yangilangan `Child` (avvalgidek). Yosh (`age`) qoidasi **o'zgarmadi** (mavjud 1–25: eski bola ilovasi buzilmasin; 6–18 — klient chegarasi; qaror).
- `GET /api/children/me` (YANGI, rol `CHILD`) — bola o'z yozuvini (`PUT` qaytaradigan shakl) o'qiydi, jumladan `educationLanguage` (`null` — hali tanlanmagan). Sinf (`grade`) avvalgidek `PUT /learning/profile`da.
  `GET /children/me` `GET /children/:id` dan oldin ro'yxatdan o'tgan (aks holda `me` id deb o'qilardi).
- Ota-ona `GET /children`, `GET /children/:id` ham `educationLanguage` qaytaradi.

## 7. Maktab paneli uchun qisqacha

- Student detail: `recoveryRequests` (5-bo'lim). Yangi bildirishnoma turi `CHILD_RECOVERY_REQUEST` (uz / ru matnlarini panel qo'shadi); lenta elementi `href` = `/students/view?id=<studentId>&tab=access`
  (o'quvchi kartasi, «Kirish» yorlig'i `tab=access`).
- Audit amallari (`audit.actions.<action>`): `student.credential.issue`, `student.credential.reset`, `student.recovery.reject` (modul `STUDENTS`; `params: { name }`).
- «Kirish maʼlumotlari» bo'limi faqat bog'langan o'quvchi uchun (aks holda `409 NOT_LINKED`); parol javobda bir marta — chop etish kartasi shu javobdan; chop etish kartasida `temporaryPasswordExpiresAt` («14 kun ichida kiring»).
- `HOMEROOM` hozir `students.manage` ruxsatiga ega emas: kirish maʼlumotini faqat DIRECTOR / ADMIN beradi / tiklaydi va tiklash bildirishnomasini ham faqat shular oladi. Rollar jadvalida sinf rahbariga
  `students.manage` berilsa — u o'z sinfi uchun bildirishnoma ham oladi, kartada so'rovlarni ko'radi va rad eta oladi (panel `school-panel/src/auth/permissions.ts` nusxasini sinxronlang).
- Maktab berganda / tiklaganda ota-ona push oladi (`CHILD_CREDENTIAL_SCHOOL`, 2-bo'lim) — maktab xodimlariga bu haqda ogohlantirish mumkin («ota-onaga xabar yuboriladi»).

## 8. Xatolar jadvali

| Holat | Kod | Qayerda |
|---|---|---|
| 401 | `INVALID_CREDENTIALS` | `child-login` (login yoki parol xato, bir xil) |
| 401 | `TEMP_PASSWORD_EXPIRED` | `child-login`, `child-setup` (to'g'ri, lekin 14 kunlik muddati o'tgan vaqtinchalik parol; setupToken yo'q) |
| 429 | `LOCKED` (`retryAfterSeconds`) | `child-login`, `child/password` |
| 429 | `RATE_LIMITED` (`retryAfterSeconds`) | `child-login` / `child-setup` (IP: 10 daqiqada 30 xato; 50 parallel), `child-recovery` (IP 30/sutka, login 3/sutka), `child/password` (10 / 15 daqiqa), `POST …/credentials` ota-ona (20 / 10 daqiqa) |
| 401 | `SETUP_TOKEN_INVALID` | `child-setup` |
| 400 | `WEAK_PASSWORD` (`reason`) | `child-setup`, `child/password` |
| 400 | `WRONG_PASSWORD` | `child/password` |
| 404 | `NO_CREDENTIAL` | `child/password` (login berilmagan bola) |
| 409 | `PASSWORD_CHANGED` | `child/password` (parallel almashtirish / tiklash) |
| 401 | `SESSION_REVOKED` (`reason`) | `auth/refresh` |
| 409 | `LOGIN_TAKEN` | `POST …/credentials` |
| 404 | `CHILD_NOT_FOUND` / 403 `FORBIDDEN` | ota-ona yo'llari (noma'lum / begona bola) |
| 404 | `REQUEST_NOT_FOUND` / 409 `ALREADY_RESOLVED` | tiklash so'rovini rad etish |
| 404 | `NOT_FOUND` | `GET auth/child-recovery/:id` (bir xil, har qanday sabab) |
| 409 | `NOT_LINKED` / `STUDENT_ARCHIVED` | maktab yo'llari |
| 403/404 | `FORBIDDEN` / `NOT_FOUND` (maktab xatolari) | ruxsat / doira / boshqa maktab |
| 403 | `FORBIDDEN` | `auth/device-link/create` (bola tokeni) |
| 400 | (class-validator) | noto'g'ri tana, jumladan `device.hostsControl` boolean emas |

## 9. Xavfsizlik (qisqacha)

Mavjudlik fosh bo'lmaydi (bir xil 401 / 202 / 404, soxta bcrypt, soya blok, javobdan keyingi ta'sirlar, limit kaliti login matni, poll'da so'ralgan kanal, login va tiklash yo'lida bir xil DB so'rovlari soni);
brute-force (qator qulfi, 5/15 daqiqa, parol almashtirish yo'lida ham qulf ostida qayta tekshiruv va 10/15 daqiqa throttle, faqat xatolarni sanaydigan IP limiti + parallel portlashga qarshi 50 ta chegarasi);
kirish va sessiya ochilish orasidagi "poyga" yopilgan (tiklash / blok kirib qolsa sessiya ochilmaydi); setupToken (alohida kalit + `aud`, bir martalik, boshqa bolaga o'tmaydi); parol faqat bcrypt (12),
vaqtinchalik parol bir marta, 14 kun va `no-store`, hech qayerda ochiq emas; poll token faqat xesh; bola IP / User-Agent saqlanmaydi; push neytral, xodim bildirishnomasi faqat ism + sinf;
barcha egalik tekshiruvlari (ota-ona -> o'z bolasi, xodim -> o'z maktabi va sinfi, so'rov -> o'z bolasi va kanali); WebSocket yopilgan sessiyaga ulanmaydi va tiklashda uziladi;
`device-link/create` faqat ota-ona (bola 3-sessiya chegarasini aylanib o'tolmaydi); ota-onaning kirish maʼlumotini berishi throttle bilan (`LOGIN_TAKEN` orqali login sinash cheklangan).

## 10. Qarorlar va og'ishlar (kontraktga nisbatan)

1. **5-noto'g'ri parolning o'zi `429 LOCKED`** (kontrakt: "5 wrong … → 429 (also while locked)" — blok qo'yilgan urinishning o'zi ham 429).
2. **Mavjud bo'lmagan loginlar uchun xotirada soya blok** — "ochmaydi" talabi shuni talab qiladi; ko'p instansiyada har instansiyaga alohida (hozir bitta).
3. `ChildCredential`ga qo'shimcha `failed_window_started_at` (aniq "15 daqiqada 5"); `users.created_via`, `user_sessions.is_main` (qurilma roli); `child_recovery_requests.requested_channel` (poll uchun).
4. Berilgan `login` yaroqsiz bo'lsa **xato emas, taklif qilinadi** (kontrakt: "given if valid & free, else suggested"); band bo'lsa 409. Qayta tiklashda `login` e'tiborsiz.
5. `GET /children/me` oldin yo'q edi (`:id` ga tushib 404 berardi) — qo'shildi. `age` oralig'i 1–25 qoldi (6–18 klientda; koordinator qarori).
6. Tiklash so'rovi ko'rinishi `{ id, channel, status, createdAt }`; rad etish `200` + ko'rinish (kontraktda tana aytilmagan). Ota-ona faqat o'ziga yuborilgan (`PARENT`) so'rovlarni ko'radi/rad etadi, xodim — `SCHOOL` (koordinator qarori: ota-ona maktab kanalini ko'rmaydi).
7. Hal bo'lgan (RESTORED / REJECTED) so'rovning xodim bildirishnomasi o'chiriladi (eskirgan "harakat kerak" yozuvi qolmasin).
   **Koordinator qarori:** xodim bildirishnomasi faqat ish qila oladiganlarga (faol, `students.manage`, doirasi o'quvchini qamraydi); hech kim mos kelmasa direktorga (5-bo'lim). Kontraktdagi "HOMEROOM + ADMIN" qattiq yozilmadi.
8. Sessiyalar ro'yxati elementlariga `paired: false` / `main`; juftlangan qurilma tiklashdan keyin ro'yxatda yo'q.
9. Sessiya yopilishi hamma yo'lda saqlanadi, jumladan eski yo'llar (logout, `/auth/sessions`, QR, 2-qurilma havolasi, qurilma almashtirish so'rovi) — `revokedReason` + `session:closed`.
10. Eskirgan tiklash so'rovlari 30 kundan keyin o'chadi (kunlik cron `child-recovery-retention`).
11. `SCHOOL` kanal bo'lib, bola maktabga bog'lanmagan / arxivlangan / maktab to'xtatilgan bo'lsa so'rov `PARENT` kanaliga o'tadi (bola kutmasdan yo'qolmasin) — samarali kanal `channel`, bola so'ragani `requested_channel` (poll shuni qaytaradi).
12. **Oila kodi bilan o'zaro ta'sir:** hech qachon juftlanmagan bola birinchi marta login bilan kirsa, bola foydalanuvchisi yaratilib `childUserId` o'rnatiladi, shuning uchun keyingi `POST /auth/child-pair`
    eski qoida bo'yicha `409 ALREADY_PAIRED` beradi (xavfsizlik: faol bola akkauntini 5 xonali kod bilan egallab bo'lmaydi). Ota-ona «Qayta ulash» QR'idan foydalanadi (yangi juftlangan qurilma asosiy bo'ladi).
13. **IP limiti faqat xatolarni sanaydi** (koordinator qarori; oldin: har bir so'rov). 30 / 10 daqiqa, muvaffaqiyatli kirish limitni yemaydi; tiklash so'rovi IP limiti 10 -> 30 / sutka.
14. **Maktab bergan / tiklagan bo'lsa ota-onaga neytral push** `CHILD_CREDENTIAL_SCHOOL` (koordinator qarori; shaffoflik).
15. **Vaqtinchalik parol 14 kun** (koordinator qarori): `TEMP_PASSWORD_EXPIRED`, `temporaryPasswordExpiresAt` (GET ko'rinishida `null` bo'lishi mumkin; POST javobda har doim).
16. **Access token qarori:** yopilgan sessiyaning access tokeni 15 daqiqagacha stateless amal qiladi (o'zgarmaydi); yangilash bloklanadi, WebSocket ulanishi va hodisalar to'xtatiladi.
17. `device.hostsControl` va `child.parentId` (OK javobda) — koordinator qo'shimchalari (3.1, 3.4).
18. `POST /auth/device-link/create` faqat `PARENT` (xavfsizlik ko'rigi): bola tokeni sessiya chegarasini aylanib o'tmasin. Ota-ona ilovasi (`Farzandim/lib/features/auth`) faqat ota-ona sifatida chaqiradi.
19. **Migratsiya joyida yangilandi** (relizdan oldin): `requested_channel` ustuni `20261109090000_kirish_auth` ichiga qo'shildi (alohida migratsiya emas). Bu migratsiyaning avvalgi qoralamasini ishlatgan mahalliy bazalar qayta yaratilishi kerak.
20. Maktab tomonidagi `signOutDevices` standarti `true` (kontrakt): maktab tiklaganda ota-ona juftlagan nazorat qurilmasi ham chiqadi — shuning uchun ota-onaga push (14) kerak.
21. Lenta elementi `href` (koordinator, panel talabi): `/students/view?id=<studentId>&tab=access` — bir xil ismli o'quvchilar adashmasligi uchun (oldin `null`).

## 11. Ma'lumotlarni o'chirish

To'rt yo'lda ham bola kirish maʼlumotlari (login / xesh), tiklash so'rovlari va ularga bog'liq xodim bildirishnomalari (`child-recovery:<id>`) o'chadi:
bola o'z akkauntini (`ChildDataPurgeService.deleteChildAccount` — profil qoladi, shuning uchun aniq o'chiriladi), ota-ona bola profilini (`purgeChildProfile`), ota-ona o'z akkauntini (`UsersService.deleteAccount`),
admin foydalanuvchini (`AdminUsersService.deleteUser`). Umumiy yordamchi: `modules/child-auth/child-auth-purge.ts`. Sessiyalar foydalanuvchi bilan cascade o'chadi.

## 12. Deploy eslatmalari

- `main`ga merge = prod deploy (+ `prisma migrate deploy`). Migratsiya faqat qo'shuvchi; orqaga qaytarish: 2 jadval, 3 enum va 6 ustunni `DROP` qilish yetarli (eski kod ishlatmaydi).
- Yangi env yo'q (setupToken kaliti `JWT_ACCESS_SECRET`dan maqsadli hosila). Throttler / soya blok / IP xato hisobi xotirada — qayta ishga tushganda nolga tushadi va ko'p instansiyada har instansiyaga alohida
  (DB asosidagi himoya baribir ishlaydi: hisob bloki 5 / 15 daqiqa, bola uchun 3 / sutka ta'sir).
- IP limiti endi faqat XATOLARNI sanaydi: maktab Wi-Fi'sida (NAT) dars boshida ko'p bola bir vaqtda kirsa ham limitga tushmaydi (faqat xato urinishlar yig'ilsa).
- WebSocket ulanishida ≤ 2 ta indeksli so'rov qo'shildi (yopilgan sessiya tekshiruvi); baza xatosida ulanish avvalgidek ruxsat etiladi.
- Kunlik cron `child-recovery-retention` (03:40) ro'yxatdan o'tadi.

## 13. Testlar

Unit (`src/modules/child-auth/*.spec.ts`, `auth/session-revocation.spec.ts`, `school/common/staff-recipients.spec.ts`, `common/realtime/realtime.gateway.spec.ts`, `child-data-purge`): login formati / transliteratsiya / taklif,
parol siyosati, vaqtinchalik parol muddati, blok holat mashinasi va soya limiter (soxta soat), siljuvchi xato hisoblagich va IP limiti, setupToken, `ChildLoginService` (soxta soat bilan blok, soxta bcrypt, muddat,
IP limiti, setup / almashtirish), `ChildSessionsService` (qurilma roli, `hostsControl`, qayta tekshiruv), `ChildCredentialsService` (shaffoflik push'i, ko'rinishlar), tiklash servisi, DTO (`hostsControl`), throttle'lar, WebSocket handshake.
E2E (haqiqiy Postgres; `kirish-*.e2e-spec.ts`, yordamchilar `kirish-fixtures.ts`): `kirish-credentials` (ota-ona), `kirish-credentials-school` (maktab + shaffoflik push'i), `kirish-login`, `kirish-ip-limits`, `kirish-temp-password`,
`kirish-setup-token`, `kirish-sessions`, `kirish-devices` (qurilma roli + `hostsControl`), `kirish-recovery`, `kirish-recovery-notify`, `kirish-recovery-manage`, `kirish-profile-purge`, `kirish-regression`.
Natijalar yakuniy hisobotda.

## 14. Qarorlar bilan yopilgan savollar va qolganlari

Yopilgan (koordinator qarori): (1) IP limiti — faqat xatolar sanaladi (10 daqiqada 30; tiklash so'rovi 30 / sutka); (2) maktab bergan / tiklagan bo'lsa ota-onaga neytral push — ha (`CHILD_CREDENTIAL_SCHOOL`);
(3) vaqtinchalik parol muddati — 14 kun (`TEMP_PASSWORD_EXPIRED`, `temporaryPasswordExpiresAt`); (4) yopilgan sessiyaning access tokeni 15 daqiqagacha amal qiladi — o'zgarmaydi; (5) `age` 1–25 qoladi;
(6) ota-ona maktab kanalidagi so'rovlarni ko'rmaydi.

Ochiq qolganlari:
1. Soxta (soya) blok, IP xato hisobi va throttler xotirada — bir nechta backend instansiyasiga o'tilganda umumiy ombor (Redis) kerak bo'ladi.
2. Maktab tiklaganda (`signOutDevices: true`) ota-ona juftlagan nazorat qurilmasi ham chiqadi (kontrakt shunday); maktab tiklashda `signOutDevices` standartini `false` qilish kerakmi?
3. Maktab yo'lidagi `POST …/credentials` uchun alohida throttle yo'q (xodim autentifikatsiyasi + `students.manage` yetarli deb hisoblandi); kerak bo'lsa ota-onadagidek qo'shiladi.
