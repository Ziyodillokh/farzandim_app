# FARZANDIM

## Yagona Raqamli Ekotizim

**Bolalar uchun Rivojlanish Platformasi · Ota-onalar uchun Xavfsiz Nazorat**

| Maydon | Qiymat |
|--------|--------|
| Hujjat turi | Mahsulot Kontseptsiyasi (Product Concept Document) |
| Versiya | 1.0 — Yagona birlashtilgan hujjat |
| Sana | 2026 |
| Platforma | iOS / Android / Web Admin/Backend |
| Maqsad auditoriya | O'zbekistondagi ota-onalar va 6–18 yoshli bolalar |

---

## 1. Asosiy G'oya va Pozitsionlash

"Farzandim" — bu nazorat ilovasi emas. Bu bola uchun rivojlanish platformasi bo'lib, ota-onaga shaffof nazorat paneli beradi. Texnik jihatdan bitta ekotizim — lekin ikki tomonlama tajriba.

### Bolaning ko'rishi

- Olimpiada va konkurslar — bilimini sinash, sertifikat olish
- Elektron kutubxona — audikitoblar
- Foydali kontent feed — yoshga mos video, infografika, maqolalar
- FARO – chat bot
- XP va status tizimi — o'sib borish, yutuqlar, liderboard
- Xavfsiz messenjer — faqat ota ona bilan

### Ota-onaning ko'rishi

- Ekran vaqti statistikasi — qaysi ilovada qancha vaqt
- Real-time geolokatsiya va geozonar — maktab, uy chegaralari
- SOS signal — favqulodda holatda koordinata
- Xavf indikatori — xavfli kalit so'zlar, anomal faollik
- Rivojlanish paneli — bolanining XP, darajasi, qaysi moduldagi faolligi
- AI tavsiyalar — "kitobxonlik yaxshi ketyapti, olimpiadaga tayyorlik qo'shaylik"

**Psixologik kalit:** Bola "nazorat ilovasi"ni o'chirishga urinmaydi — chunki u Farzandim = o'zining rivojlanish platformasi deb qabul qiladi. XP va status tizimi bolani ixtiyoriy ravishda platformada ushlab turadi — majburlov emas, motivatsiya asosida.

---

## 2. Tizim Arxitekturasi

Ekotizim quyidagi 6 ta asosiy komponentdan iborat:

| Komponent | Ko'rinish | Asosiy vazifa |
|-----------|-----------|---------------|
| Child App | Ochiq | Bola uchun rivojlanish platformasi: kontent, kutubxona, olimpiada, profil, messenjer |
| Child Agent | Yashirin | Fon rejimida: ekran vaqti, blok, geolokatsiya, geozona, anti-tamper, SOS, telemetry, shagomer |
| Parent Dashboard | Ochiq | Ota-ona ilovasi: statistika, limitlar, geozonar, SOS, AI tavsiyalar, hisobotlar |
| Backend + AI Engine | Markaziy | RBAC, 2FA, AES-256, gamifikatsiya engine, tavsiya tizimi, analytics, anti-cheat |
| Admin Panel | Web | Moderatsiya, olimpiada boshqaruvi, video va audiokitoblar joylash, bildirishnomalar yuborish, audit jurnali, hisobot eksport |
| Integratsiyalar | Tashqi | FCM/APNS, SMS Gateway, Payment Gateway |

### 2.1. Ikki Komponentli Bola Arxitekturasi

Child qurilmasida ikki alohida komponent ishlaydi:

**Child App — Ko'rinadigan Qism**

- Bola interfeysida to'liq ko'rinadigan rivojlanish platformasi
- FARO chat bot, foydali kontent, elektron kutubxona, olimpiada va konkurslar
- Xavfsiz messenjer, profil, XP va gamifikatsiya modullari
- Ota-ona bilan bog'liqlik: bildirishnomalar, vazifalar

**Child Agent — Yashirin Fon Xizmati**

- Android: Device Owner / Work Profile MDM mexanizmi orqali
- iOS: Screen Time / Family Controls API orqali (cheklangan)
- Bola interfeysida alohida ilova sifatida ko'rinmaydi
- Anti-tamper: ruxsatsiz o'chirishni aniqlash va bloklash
- Telemetry: shagomer, faqat agregat statistika, kontent matni yig'ilmaydi

---

## 3. Funksional Modullar

### 3.1. Child App Modullari

#### 3.1.1. Dashboard (Bosh Sahifa)

- Bugungi maqsadlar va ularning bajarilish holati
- Tavsiya etilgan kontent va kutilayotgan musobaqalar
- Qolgan ekran vaqti va kunlik progress
- Mening progressim — XP, streak, yutuqlar

#### 3.1.2. Olimpiadalar Moduli

**Maqsad:** fanlar bo'yicha bolalar bilimini chuqur baholash va iste'dodlarni aniqlash.

- **Fanlar:** matematika, ona tili, ingliz tili, fizika, kimyo, IT / mantiqiy fikrlash
- **Savol turlari:** test (1 to'g'ri), bir nechta to'g'ri, hisob-kitobli, qisqa matnli
- **Tuzilish:** fan, sinf/yosh, savollar soni, vaqt limiti, qiyinlik darajasi
- **Avtomatik baholash:** to'g'ri = ball, noto'g'ri = 0, vaqt hisobga olinadi
- **Natijalar:** jami ball, fan bo'yicha reyting, respublika/maktab reytingi
- **Sertifikat:** elektron diplom generatsiyasi
- **Anti-cheat:** tab change, timeout, shubhali faollik aniqlash

**UI/UX:**

- **Bola:** asosiy ekran (fan tanlash) → test ekrani (1 savol = 1 ekran, katta shrift, taymer) → natija ekrani (ball, o'rin, diplom)
- **Ota-ona:** qaysi fan kuchli, dinamika (oylik), tavsiya etilgan fanlar

#### 3.1.3. Elektron Kutubxona

- Elektron audio kitoblar
- Progress monitoringi
- "Tugatdim" belgisi → avtomatik achievement va XP
- Kategoriyalar: fan, badiiy, o'z-o'zini rivojlantirish, tarix

#### 3.1.4. Foydali Kontent Feed

- Video, rasm, matn, infografika — yoshga mos
- Kategoriyalar: IT, matematika, psixologiya, kitobxonlik, tarix, sport, san'at
- Like / koment — tashqi tarmoqqa emas
- Kontent joylash imkoni: moderatsiyadan keyin XP beriladi

#### 3.1.5. Xavfsiz Messenjer

- Ota-ona ↔ bola to'g'ridan-to'g'ri aloqa

#### 3.1.6. Profil va Natijalar

- Shaxsiy status (Level / Rank)
- Yutuqlar va bedjlar (achievements)
- Sertifikatlar arxivi
- Reyting tarixi va liderboard

### 3.2. Parent Dashboard Modullari

- Ekran vaqti va ilovalar statistikasi — qaysi ilovada qancha vaqt
- Geolokatsiya: asosiy va real-time
- Safe Zone: uy/maktab chegarasiga kirish/chiqish bildirishnomasi
- SOS: favqulodda holatda koordinata va signal
- Limit va blok: ilovalar bo'yicha vaqt cheklovi, kontent filtri
- Ilova o'rnatishni cheklash
- Rivoj progress paneli: bolanining XP, darajasi, qaysi modul foydali
- AI tavsiyalar: "matematika olimpiadasiga tayyorlik qo'shaylik"
- Hisobotlar: haftalik, oylik, choraklik (PDF/CSV eksport)

### 3.3. Child Agent Vazifalari

- Ekran vaqti va ilovalar faoliyati monitoringi (kontent matnini o'qimasdan)
- Ilova uchun vaqt limiti va bloklash siyosati
- Geolokatsiya va geozona aniqlash
- Shagomer hisoblash
- SOS holatida koordinatalarni yuborish
- Anti-tamper: ruxsatsiz o'chirishni aniqlash
- Device binding: bola qurilmasini ota-ona akkauntiga (QR/kod orqali) bog'lash
- Telemetry: faqat agregat statistika yuboriladi

### 3.4. AI Rivoj Engine

- **Academic Analytics:** fanlar bo'yicha kuchli/kuchsiz tomonlar, baholar dinamikasi va prognoz
- **Behavioral Analytics:** ekran vaqti va faoliyat patterni, raqamli balans indeksi
- **Safety & Risk Analytics:** xavfli kalit so'zlar, risk darajasini aniqlash
- **Recommendation Engine:** kontent, kitob, kurs va olimpiadalarni individual tavsiya
- **Career Orientation (v3):** RIASEC va Klimov testlari asosida kasblar xaritasi

---

## 4. Gamifikatsiya Tizimi

Gamifikatsiya — platformaning eng muhim uzoq muddatli ushlab turish (retention) mexanizmi. Bola o'yinga emas, balki o'z bilim va mahoratiga sarmoya qiladi.

### 4.1. Status Progressi

| Status | Daraja | XP diapazoni | Ochilgan imkoniyatlar |
|--------|--------|-------------|----------------------|
| Boshlovchi | Lv 1–3 | 0 – 300 XP | Asosiy kontent, olimpiadalar |
| Izlanuvchi | Lv 4–7 | 300 – 900 XP | Kengaytirilgan kontent kategoriyalari |
| Bilimdon | Lv 8–12 | 900 – 2000 XP | Maxsus olimpiadalar, premium sertifikatlar |
| Lider | Lv 13–20 | 2000 – 5000 XP | Mentor chat, bonus kitoblar va kurslar |
| Mentor | Lv 20+ | 5000+ XP | Yil yakuni real mukofot, maxsus diplom |

### 4.2. XP Beriladi — Qaysi Harakatlar Uchun

| Harakat | XP miqdori |
|---------|-----------|
| Audiokitobni tugatish | +5 XP |
| Olimpiadada ishtirok etish | +10 XP |
| Kuniga 3000 qadan yurish | +20 XP |
| Olimpiadada g'olib yoki sovrindor bo'lish | +50 XP |
| Ijodiy konkursda ishtirok | +25 XP |
| Kurs darsini tugatish | +20 XP |
| Kunlik maqsadni bajarish | +10 XP |
| Haftalik streak (uzluksiz faoliyat) | +75 XP |
| Foydali kontent joylash (moderatsiyadan keyin) | +25 XP |

### 4.3. Achievements (Nishonlar)

- "1-kitob o'qib tugatdim" — birinchi kitob
- "10 kun streak" — 10 kun uzluksiz faoliyat
- "Matematika viktorinasi TOP-10"
- "Olimpiada sovrindori"
- "Kontent yaratuvchi" — 5 ta moderatsiyadan o'tgan post
- "Yordamchi" — boshqa bolaga to'g'ri javob

**Qoida:** kontent joylash XP — faqat moderatsiyadan keyin. G'oliblik XP — turnir natijasidan avtomatik.

---

## 5. Monetizatsiya Modeli

To'rt bosqichli freemium model — O'zbekiston bozorining to'lov qobiliyatini hisobga olgan holda tuzilgan.

| Funksiya | FREE | BASIC | STANDARD | PREMIUM |
|----------|------|-------|----------|---------|
| Ekran vaqti (umumiy statistika) | ✓ | ✓ | ✓ | ✓ |
| SOS signal | ✓ | ✓ | ✓ | ✓ |
| Bola profili (1 ta) | ✓ | ✓ | ✓ | ✓ |
| Ekran vaqti limiti | — | ✓ | ✓ | ✓ |
| Asosiy geolokatsiya | — | ✓ | ✓ | ✓ |
| Ilova o'rnatishni cheklash | — | ✓ | ✓ | ✓ |
| Haftalik hisobot | — | ✓ | ✓ | ✓ |
| Real-time geolokatsiya | — | — | ✓ | ✓ |
| Ilovalar vaqt cheklovi | — | — | ✓ | ✓ |
| Kontent filtri | — | — | ✓ | ✓ |
| Pulli kurslar / konkurslar | — | — | ✓ | ✓ |
| Bir profildan n-ta bola boshqarish | — | — | — | ✓ |
| **OYLIK TO'LOV** | **Bepul** | **25 000 so'm** | **35 000 so'm** | **60 000 so'm** |
| **YILLIK TO'LOV (2 oy chegirma)** | **—** | **250 000 so'm** | **350 000 so'm** | **600 000 so'm** |

### 5.1. Tarif Strategiyasi

- **FREE:** ilova o'rnatishni osonlashtiradi, onboarding to'siqsiz — foydalanuvchi bazasini tezda o'stiradi
- **BASIC:** asosiy nazorat ehtiyojini hal qiladi — keng ommaviy segment uchun
- **STANDARD:** real-time geolokatsiya va kontent filtri — xavotirli ota-onalarning asosiy dardi
- **PREMIUM:** ko'p farzandli oilalar — eng yuqori LTV segment

**Muhim:** Bola XP orqali o'sib, yangi kurslarga kirmoqchi bo'lganda ota-onasidan STANDARD tarifga o'tishni so'raydi. Bola o'zi tarif upgrade uchun lobbying qiladi — bu eng samarali upsell mexanizmi.

---

## 6. Texnik va Xavfsizlik Talablari

### 6.1. Xavfsizlik Standartlari

- **Transport:** TLS 1.3 (minimum TLS 1.2)
- **Saqlashda shifrlash:** AES-256 (GCM rejimi)
- **Parollar:** Argon2 / bcrypt + salt
- **Autentifikatsiya:** 2FA (SMS / Authenticator) — ota-ona va admin uchun majburiy
- **Avtorizatsiya:** RBAC (ota-ona / bola / admin / operator / support)
- **Audit jurnallari:** kim/qachon/nima o'zgartirdi — tamper-evident saqlash
- **Device binding:** QR/kod orqali bola qurilmasini ota-ona akkauntiga bog'lash

### 6.2. Shaxsiy Ma'lumotlar va Muvofiqlik

- **Lokalizatsiya:** O'zbekiston fuqarolari ma'lumotlari — O'zbekiston hududidagi serverlarda
- **Granular consent:** ma'lumot turi bo'yicha alohida ruxsat — qaytarib olish imkoni
- **Data minimization:** faqat kerakli minimum — kontent matni, klaviatura yozuvlari yig'ilmaydi
- **DPIA:** xavflar, ta'sir, kamaytirish choralari

---

## 7. Ilovalar (Annex)

| Annex | Mazmun |
|-------|--------|
| A1 | iOS / Android funksional cheklovlar matritsasi |
| A2 | DPIA shabloni va risk register |
| A3 | Ma'lumotlar reestri (data inventory) |
| A4 | Intsidentlar boshqaruv reglamenti (SOC-lite) |
| A5 | Arxitektura diagrammasi (modul asosida) |
| A6 | Gamifikatsiya XP hisoblash algoritmi |
| A7 | Anti-cheat texnik spetsifikatsiyasi |

---

*Farzandim — Yagona Raqamli Ekotizim | Mahsulot Kontseptsiyasi v1.0 | Maxfiy*
