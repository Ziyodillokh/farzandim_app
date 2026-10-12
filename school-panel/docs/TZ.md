# Parvoz School — maktab boshqaruv paneli: texnik topshiriq (TZ)

> Versiya 1.0 · 2026-10-12 · Holat: **demo (mock-ma'lumot)**, keyin Parvoz backend'iga ulanadi.
> Manba: "PARVOZ SCHOOL — Maktab, ota-ona va o'quvchini birlashtiruvchi raqamli ekotizim" konsepsiyasi.

---

## 1. Maqsad va doira

**Maqsad.** Maktab rahbariyati va vakolatli xodimlar uchun yagona veb-panel: dars vaqtida telefonlardan
foydalanish tartibi (School Mode), davomat (Smart Attendance), ota-onalar bilan aloqa (xabarlar, Smart
Reminder), o'quvchi ovozi (Parvoz Care — Bola ovozi), ta'limiy faollik (Growth Learning) va maktab
tuzilmasi (sinflar, o'quvchilar, xodimlar).

**Demo bosqichi (ushbu TZ).** Bitta uydirma maktab. Barcha ma'lumotlar brauzerda saqlanadigan mock.
Panel to'liq "ishlaydi": login, rollar, qo'shish/tahrirlash/o'chirish, qidiruv, filtr, saralash,
sahifalash, eksport (CSV, chop etish/PDF), jonli hodisalar simulyatsiyasi. Manzil:
`https://farzandimedu.uz/school/`.

**Doiradan tashqari (demo).** Haqiqiy to'lov, haqiqiy SMS/push, haqiqiy telefonlarga cheklov qo'yish,
haqiqiy psixologik xizmat. Bular Parvoz Parents / Parvoz Growth ilovalari va backend orqali keyingi
bosqichda.

**Tamoyillar.**
- Maktabdagi mavjud dasturlarni almashtirmaydi — ularni bog'laydi.
- Bolani "doimiy kuzatish" emas: xavfsizlik + mustaqillik + o'z fikrini bildirish huquqi.
- Har xodim faqat o'ziga kerakli ma'lumotni ko'radi (eng kam huquq tamoyili).
- Parvoz Parents orqali ota-ona oladigan shaxsiy nazorat ma'lumotlari maktabga **ochiq emas**.
- Bola ovozi ma'lumotlari — eng yuqori maxfiylik darajasi.

---

## 2. Rollar

| Rol | Kim | Doira |
|---|---|---|
| **Direktor** | Maktab rahbari | Butun maktab. Bola ovozi — faqat umumlashgan, anonim natija |
| **Administrator** | O'quv ishlari bo'yicha direktor o'rinbosari / kotib | Tuzilma, davomat, School Mode, xabarlar, eslatmalar |
| **Sinf rahbari** | O'qituvchi | Faqat o'z sinfi (o'quvchilar, davomat, sinf ota-onalariga xabar, School Mode istisnosi) |
| **Psixolog** | Maktab psixologi | Bola ovozi to'liq: murojaatlar, so'rovnomalar. Boshqa modullardan — faqat o'quvchi ismi/sinfi |
| **Navbatchi** | Kirish nuqtasidagi xodim | Kirish nuqtasi (kiosk) va bugungi davomat |

### 2.1 Ruxsatlar matritsasi

| Imkoniyat | Direktor | Admin | Sinf rahbari | Psixolog | Navbatchi |
|---|---|---|---|---|---|
| Sozlamalar, xodimlar, rollar, demo-tiklash | ✅ | — | — | — | — |
| Sinf/o'quvchi/ota-ona boshqaruvi | ✅ | ✅ | ko'rish + ota-ona ulash (o'z sinfi) | ko'rish (ism/sinf) | — |
| School Mode boshqaruvi, favqulodda o'chirish | ✅ | ✅ | ko'rish + istisno (o'z sinfi) | — | — |
| Davomat — ko'rish | ✅ | ✅ | ✅ (o'z sinfi) | — | bugun |
| Davomat — belgilash | — | ✅ | ✅ | — | ✅ |
| Davomat — tuzatish, erta ketishni tasdiqlash | — | ✅ | ✅ | — | — |
| Kirish nuqtasi (kiosk) | — | ✅ | — | — | ✅ |
| Xabarlar maktab bo'yicha / eslatmalar / to'lov sanalari | ✅ | ✅ | sinf xabari | — | — |
| Bola ovozi — umumlashgan natija | ✅ | ✅ | — | ✅ | — |
| Bola ovozi — shaxsiy murojaat, so'rovnoma | — | — | — | ✅ | — |
| Growth Learning | ko'rish | tayinlash | tayinlash (o'z sinfi) | — | — |
| Hisobotlar eksporti, audit jurnali | ✅ | ✅ | — | — | — |

Talab: ruxsat **uch joyda** tekshiriladi — menyu (ko'rinmaydi), sahifa ("Ruxsat yo'q" ekrani), amal
(tugma yo'q + servis rad etadi).

### 2.2 Demo hisoblar

| Login | Parol | Rol |
|---|---|---|
| `direktor` | `Direktor2026` | Direktor |
| `admin` | `Admin2026` | Administrator |
| `sinf7a` | `Sinf2026` | 7-A sinf rahbari |
| `psixolog` | `Psixolog2026` | Psixolog |
| `navbatchi` | `Navbatchi2026` | Navbatchi |

---

## 3. Umumiy talablar

- **Til:** o'zbek (lotin, asosiy) va rus. Yuqori panelda almashtirish, tanlov eslab qolinadi.
- **Dizayn:** Parvoz brendi (ko'k #216BFF / #3C82FF / #508AFF, logo), yorug' va qorong'i rejim,
  desktop + planshet (≥768 px), kiosk sahifasi — to'liq ekran.
- **Maktab brendi:** maktab nomi, shahri va logosi Sozlamalardan o'zgaradi; "Shu maktab uchun havola"
  — nom va logo havolaga joylanadi, havolani ochgan har brauzerda shu maktab ko'rinadi.
- **Ishonch:** har o'zgarish audit jurnaliga (kim, nima, qachon, oldin/keyin). Xavfli amallar —
  tasdiqlash oynasi bilan.
- **Eksport:** jadvallar CSV (Excel to'g'ri ochadi: UTF-8 BOM, `;`), hisobotlar — chop etish/PDF.
- **Yuklanish holatlari:** skelet, bo'sh holat, xato holati — har ro'yxatda.
- **Qulaylik:** global qidiruv (Ctrl/⌘ + K) — o'quvchi, sinf, xodim, sahifa.
- **Maxfiylik:** sahifalar qidiruv tizimlarida indekslanmaydi (noindex). Demo'da "uydirma ma'lumotlar"
  belgisi.

---

## 4. Modullar

### 4.1 Bosh sahifa (Dashboard)
- KPI: bugun keldi / kechikdi / kelmadi (foiz bilan), hozir School Mode faol sinflar, Parvoz'ga
  ulangan ota-onalar ulushi, ochiq so'rovlar (tekshiruv, erta ketish).
- Grafiklar: haftalik davomat trendi, sinflar bo'yicha davomat, School Mode qo'llanish holati.
- "Hozir" lentasi: oxirgi kirish/chiqishlar, ogohlantirishlar.
- Yaqin eslatmalar va tadbirlar. Tezkor amallar (xabar yuborish, o'quvchi qo'shish, kiosk).
- Rolga qarab ko'rinish: sinf rahbari — o'z sinfi kartochkasi; psixolog — Bola ovozi xulosasi;
  navbatchi — kiosk va bugungi taxta.

### 4.2 School Mode — dars vaqtida telefon tartibi
- **Smenalar va qo'ng'iroq jadvali:** smena (1-smena 08:00, 2-smena 13:30), darslar va tanaffuslar
  (`HH:MM`), hafta kunlari.
- **Siyosat:** cheklanadigan toifalar (O'yinlar, Ijtimoiy tarmoqlar, Video), har doim ruxsat etilgan
  (qo'ng'iroq/SMS, favqulodda, maktab tasdiqlagan ta'lim ilovalari ro'yxati).
- **Sinflarga tayinlash:** sinf → smena → siyosat; sinf kartochkasida "hozir faol / tanaffus / tugagan".
- **Jonli holat:** sinf bo'yicha qurilmalar: qo'llangan / ruxsat yo'q / telefon yo'q / oflayn;
  iOS / Android ulushi. Muammoli qurilmalar ro'yxati (ota-onaga eslatma yuborish tugmasi).
- **Vaqtinchalik istisno:** o'quvchi, muddat (15 daq – kun oxirigacha), sabab (majburiy), kim
  bergan — jurnalga.
- **Favqulodda o'chirish:** butun maktab yoki sinf uchun darhol (sabab majburiy), qayta yoqish.
- **Xavfsizlik qoidalari:** cheklov jadval tugashi bilan **avtomatik** tugaydi (QR chiqish
  qayd etilmasa ham); bayram kunlari ishlamaydi; favqulodda aloqa doim ochiq.
- **Bayram kunlari** kalendari.
- Eslatma: iOS va Android imkoniyatlari farq qiladi (iOS — Apple Family Controls, ota-ona tasdig'i).

### 4.3 Smart Attendance — davomat
- **Bugungi taxta:** sinflar kartochkalari (keldi/kechikdi/kelmadi/erta ketdi), sinfga kirsa —
  o'quvchilar ro'yxati, qo'lda belgilash.
- **Jonli oqim:** kirish/chiqish hodisalari real vaqtda (manba: QR, kiosk, qo'lda).
- **Kirish nuqtasi (kiosk):** maktab qurilmasida to'liq ekran; har 30 soniyada yangilanadigan
  bir martalik QR; o'quvchi kodi/ismi bo'yicha qo'lda belgilash; telefoni yo'q o'quvchi uchun ham.
- **Kechikish qoidasi:** smena boshlanishidan + N daqiqa (sozlanadi, standart 10).
- **Tuzatish:** status o'zgartirish faqat sabab bilan, tarixda saqlanadi.
- **Erta ketish:** so'rov (kim olib ketadi, sabab) → tasdiqlash/rad → ota-onaga xabar.
- **Ota-onaga xabar jurnali:** "farzandingiz maktabga keldi/ketdi" yuborilganlar.
- **Hisobot:** oylik, sinf bo'yicha, o'quvchi bo'yicha; CSV va chop etish.
- **Aldashga qarshi:** qisqa muddatli kod, takror ishlatish taqiqi, zid qaydlarni belgilash.
- Qoida: QR o'zi bolaning maktabda ekanini mutlaq isbotlamaydi — xodim tasdig'i imkoniyati saqlanadi.

### 4.4 O'quvchilar, sinflar, ota-onalar
- Sinflar: sinf, harf, smena, sinf rahbari, o'quvchilar soni; CRUD.
- O'quvchilar: F.I.Sh., jinsi, tug'ilgan sana, sinf, qurilma (iOS/Android/yo'q), ota-ona(lar);
  qidiruv, filtr (sinf, ulanish holati, qurilma), CSV import/eksport.
- O'quvchi kartasi: davomat tarixi (oylik kalendar), School Mode holati, ota-onalar, eslatmalar.
- Ota-onani Parvoz Parents'ga ulash: taklif kodi + QR (muddatli), holat: taklif qilinmagan /
  taklif yuborilgan / ulangan.

### 4.5 Xabarlar va Smart Reminder
- **Xabar:** auditoriya (butun maktab / sinf(lar) / tanlangan ota-onalar), sarlavha, matn, muhimlik,
  darhol yoki rejalashtirilgan; yetkazildi/o'qildi statistikasi; **Parvoz Parents telefon maketida
  oldindan ko'rish**; shablonlar.
- **Eslatmalar:** yig'ilish, imtihon, tadbir, ta'til, e'lon — sana/vaqt, auditoriya, takrorlanish.
- **To'lov eslatmalari:** har oila uchun keyingi eslatma sanasi; surish, to'xtatish, ommaviy yangilash
  (masalan, 4 oylik oldindan to'laganlar).
- **Tekshiruv so'rovlari:** ota-ona "eslatmada xato bor" desa — qutiga tushadi, maktab javob beradi.
- **Moliyaviy chegara:** platforma to'lov qabul qilmaydi, qarz hisoblamaydi; tasdiqlanmagan ma'lumot
  asosida "qarzdorsiz" xabari avtomatik yuborilmaydi.

### 4.6 Bola ovozi — Parvoz Care
- **Haftalik so'rovnoma:** 3–5 daqiqa, yosh guruhlari (1–4, 5–8, 9–11), savollar banki, javob
  majburiy emas, rozilik asosida.
- **Murojaatlar (faqat psixolog):** "Psixolog bilan gaplashmoqchiman" — yangi / jarayonda / yopildi,
  shoshilinchlik, suhbat vaqti, ichki eslatmalar. Shoshilinch (xavfsizlikka tahdid) — maxsus himoya
  protokoli; murojaat shikoyat qilingan shaxsga **hech qachon** avtomatik yuborilmaydi.
- **Umumlashgan natija (direktor, admin):** maktab / parallel / sinf kesimida, faqat **k ≥ 5**
  respondentli guruhlar; kichik guruh yashiriladi (ayirish orqali topib bo'lmasligi uchun qo'shni
  guruh ham); erkin matn yo'q; foizlar yaxlitlanadi.
- Tizim **tashxis qo'ymaydi**; xizmat favqulodda yordam o'rnini bosmaydi (ish vaqti ko'rsatiladi).

### 4.7 Growth Learning (maktab tomoni)
- Sinflarga material (audiokitob, video) va test tavsiya qilish/tayinlash, muddat.
- Sinf darajasidagi faollik: bajarilgan topshiriqlar, DON ballari (shaxsiy reyting emas —
  sinf/umumiy), qiziqishlar taqsimoti.

### 4.8 Hisobotlar, xodimlar, audit, sozlamalar
- **Hisobotlar:** davomat, School Mode qo'llanishi, xabarlar qamrovi, Bola ovozi (umumlashgan);
  davr tanlash; CSV va chop etish.
- **Xodimlar va rollar:** CRUD, rol, sinf(lar); rollar ruxsatlar jadvali (ko'rish).
- **Audit jurnali:** filtr (xodim, modul, sana), tafsilot (oldin/keyin).
- **Sozlamalar:** maktab profili (nom, shahar, logo), o'quv yili va choraklar, kechikish chegarasi,
  til, mavzu, "Shu maktab uchun havola", "Demo ma'lumotlarni tiklash".

---

## 5. Ma'lumot modeli (asosiy obyektlar)

School, Shift, BellPeriod (`no, start, end, kind: LESSON|BREAK`), Class (grade, letter, shiftId,
homeroomStaffId), Student (familiya, ism, otasining ismi, gender, birthDate, classId,
device `IOS|ANDROID|NONE`), Guardian, ParentLink (`NOT_INVITED|INVITED|LINKED`, inviteCode,
expiresAt), Staff (roleId, classIds), Role (permissions, scope `SCHOOL|OWN_CLASS`),
AttendanceRecord (date, studentId, `PRESENT|LATE|ABSENT|LEFT_EARLY`, inAt, outAt,
source `QR|KIOSK|MANUAL`, corrections[]), EarlyExitRequest, QrToken, SchoolModePolicy
(blockedCategories `GAME|SOCIAL|VIDEO`, allowedApps), SchoolModeException, DeviceStatus
(`APPLIED|NO_PERMISSION|NO_PHONE|OFFLINE`), EmergencyState, Holiday, Announcement (audience,
scheduledAt, stats), Reminder, PaymentReminder (nextDate, paused, history), VerificationRequest,
CareQuestion, CareSurvey, CareResponse (faqat psixolog yo'li), CareRequest, LearningAssignment,
AuditLog. Vaqt — `HH:MM`, hafta kunlari — ISO 1–7, sanalar — ISO 8601 (backend bilan bir xil).

---

## 6. Demo rejimi

- **Mock ma'lumot:** ~22 sinf, ~570 o'quvchi, ~45 xodim, ota-onalar; har safar bir xil (deterministik).
- **Saqlash:** brauzer xotirasi; sahifa yangilansa ham saqlanadi; "Demo ma'lumotlarni tiklash".
- **Demo soati:** ish kuni 07:00–18:00 da haqiqiy vaqt; kechqurun yoki dam olish kunida birinchi
  ochilishda avtomatik "ertalab 07:45" ssenariysi (10×; 1×/10×/60× tanlanadi, soat vidjetida
  "Ertalabni qayta boshlash") — kirishlar jonli oqimda paydo bo'ladi. Yashirin demo panel: **Ctrl + Shift + D** (kechikish, erta
  ketish, shoshilinch murojaat, tekshiruv so'rovi).
- **Ikki tab sinxron:** kiosk bir tabda, panel boshqasida — belgilangan kirish darhol taxtada.

---

## 7. Backend integratsiyasi (keyingi bosqich)

- Ma'lumot qatlami servis interfeyslari orqali: `NEXT_PUBLIC_DATA_SOURCE=mock|http`.
- Mavjud backend bilan bog'lanish nuqtalari: `Routine` (`type=SCHOOL`) — School Mode jadvali bola
  qurilmasiga; `Schedule` (BLOCK oynalari) — iOS Family Controls / Android cheklov; `GeoZone` +
  `GeoZoneEvent` — maktab hududiga kirish/chiqish (davomatni to'ldiruvchi signal); FCM — ota-onaga xabar.
- Yangi backend modullari kerak: `schools`, `classes`, `staff` (+ rollar), `attendance`,
  `announcements`, `reminders`, `care` (alohida shifrlangan saqlash, psixolog-only kirish), audit.
- Auth: real JWT + 2FA (admin-web kabi), rollar backend guard'larida.

---

## 8. Qabul mezonlari (demo)

1. `https://farzandimedu.uz/school/` ochiladi, 5 demo hisob bilan kirish ishlaydi, chiqish ishlaydi.
2. Har rol faqat o'z menyusi va sahifalarini ko'radi; taqiqlangan sahifa — "Ruxsat yo'q".
3. Barcha ro'yxatlarda qidiruv, filtr, saralash, sahifalash; qo'shish/tahrirlash/o'chirish ishlaydi,
   sahifa yangilansa saqlanadi.
4. Kiosk orqali belgilangan kirish ikkinchi tabdagi taxtada darhol ko'rinadi.
5. Direktor Bola ovozida hech qanday shaxsiy ma'lumot ko'rmaydi; k<5 guruhlar yashirin.
6. O'zbek va rus tillarida barcha matnlar tarjima qilingan.
7. CSV eksport Excel'da to'g'ri ochiladi; chop etish sahifasi toza.
8. Sozlamalarda maktab nomi/logosi o'zgaradi; "Shu maktab uchun havola" boshqa brauzerda ham ishlaydi.
9. Konsolda xato yo'q; yorug'/qorong'i rejim; planshetda qulay.

---

## 9. Texnik arxitektura

- Next.js 15 (statik eksport, `basePath: /school`), React 19, TypeScript, Tailwind CSS, Radix UI,
  TanStack Query/Table, react-hook-form + zod, recharts, date-fns.
- Papka: `school-panel/` (Parvoz monorepo). Deploy: `deploy-landing.yml` → `website/public/school/`
  → `farzandimedu.uz` (mavjud statik sayt pipeline'i, xesh tekshiruvi va avto-rollback bilan).
- Testlar: vitest (ma'lumot, ruxsatlar, k-anonimlik, tarjima pariteti), Playwright (har rol ×
  har sahifa), eksport tekshiruvi.
