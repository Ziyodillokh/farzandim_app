# Google Play — "Parvoz Parents" (ota-ona ilovasi) chiqarish qo'llanmasi

> **Maqsad: birinchi urinishda tasdiqlanish.** Bu hujjat 2026-08-18 holatiga
> ko'ra tekshirilgan HAQIQIY ma'lumotlarga asoslangan (manifest, backend,
> ishlab chiqaruvchi baza) — taxmin emas.
>
> Paket: `com.farzandim.parent` · Nom: **Parvoz Parents**
> Maxfiylik siyosati: `https://farzandimedu.uz/privacy.html`
> Play Console'da ilova allaqachon yaratilgan (Farzandim Tech hisobida),
> **"Закрытое тестирование"** trekida, 5 ta test-o'rnatish bор, lekin
> **HALI TEKSHIRUVGA YUBORILMAGAN** ("Ещё не отправлено на проверку").

---

## 0) Joriy holat — nima allaqachon qilingan (2026-08-14, Ziyodillokh, 5-agentli audit)

7 ta bloker topilib, 6 tasi tuzatilgan, 1 tasi ongli qabul qilingan xavf:

| # | Muammo | Holati |
|---|---|---|
| 1 | Reviewer 3-qurilma limitiga tushib, ilovaga kira olmasligi (409 DEVICE_LIMIT_REACHED) | ✅ `PLAY_REVIEW_PARENT_EMAIL` orqali tuzatilgan |
| 2 | Release build jimgina **debug kalit** bilan imzolanishi (CI xato bermay o'tib ketardi) | ✅ CI'ga qattiq guard qo'shilgan |
| 3 | Ilova ichi maxfiylik matnida 3 ta yozilmagan funksiya (o'z joylashuv, ovoz/video, obuna) | ✅ Qo'shilgan |
| 4 | "Create account" tugmasi aslida QR kamera ochadi (en/ru tarjima chalkashligi) | ✅ "Join account via QR" ga tuzatilgan |
| 5 | versionName kosmetik xatosi (1.0.1001 chiqib qolgan edi) | ✅ Tuzatilgan |
| 6 | Mapbox token yo'q bo'lsa xarita nomlarsiz qolishi (jim xato, 2026-08-14 haqiqiy nosozlik) | ✅ CI guard qo'shilgan |
| 7 | Play Billing siyosati — Android'da tashqi to'lovga yo'naltirish (Click) | ⚠️ **Ongli qabul qilingan xavf** — pastga qarang |

**Tekshirilgan:** `flutter analyze --fatal-infos` toza, 76/76 test o'tgan, backend `tsc` toza.

### ⚠️ Bitta qoldiq xavf: Play Billing siyosati

Google Play qoidasi: ilova ichida foydalanuvchini Play Billing'дан **BOSHQA**
to'lov usuliga (bizda — Click, tashqi checkout) yo'naltirish **taqiqlangan**.
Istisno faqat AQSh/YeIH/Hindiston/Janubiy Koreya uchun — **O'zbekiston bu
ro'yxatda YO'Q**.

- Hozir bu funksiya **yoqilgan** (`kAndroidExternalCheckoutEnabled = true`,
  `Farzandim/lib/features/settings/presentation/screens/parvoz_premium_screen.dart`).
- Ilova **yopiq testdan shu holatda o'tgan**, ega xavfni ataylab qabul qilgan.
- **KILL-SWITCH tayyor:** agar Play rad etsa — shu bitta `bool`ni `false`
  qiling, boshqa hech narsa o'zgartirish shart emas. Android'da narx/tugma/
  checkout butunlay yashiriladi (web va iOS/Apple IAP tegilmaydi).
- **Tavsiya:** birinchi topshirishda shu holicha qoldiring — agar rad
  etilsa, sabab aniq shu bo'ladi va bitta qatorlik tuzatish bilan qayta
  yuborasiz.

---

## 1) Build va imzolash

### AAB olish
GitHub → **Actions** → **"Build parent AAB (Play Market)"** → **Run workflow**
→ tugagach **Artifacts** → `parent-release-aab` → ichida `app-release.aab`.

- versionCode avtomatik: **1000 + run raqami** (Play'даги mavjud parent
  versionCode'laridan yuqori bo'lishi uchun ataylab ofset qilingan).
- Signing: `ANDROID_SIGNING_B64` secret — build-child-aab bilan **bir xil**
  keystore ("upload key" o'zgarmaydi).
- CI ichida 2 ta himoya avtomatik ishlaydi: (a) release imzo kaliti borligini
  tekshiradi, (b) Mapbox token to'g'ri formatda ekanini tekshiradi — ikkalasi
  ham yo'q/xato bo'lsa build **qasddan yiqiladi** (jim xato o'rniga).

**Birinchi safar — Закрытое тестирование trekiga qoldiring**, tekshirib
ko'ring, keyin Production'ga o'tkazing (yoki to'g'ridan-to'g'ri Production'ga
yuborish ham mumkin — Growth'да qilganimizdek).

---

## 2) Reviewer kirish ma'lumotlari (App content → App access)

Ilova login talab qiladi — reviewer sinab ko'rishi uchun **tayyor, ishlaydigan**
demo akkaunt:

```
Email: demoparvoz@gmail.com
Parol: PlayReview2026!
```

- ✅ Bu akkauntga **2-qurilma limiti qo'llanmaydi** (`PLAY_REVIEW_PARENT_EMAIL`
  backend env orqali) — reviewer istagancha qurilmadan kira oladi, 409
  xatosiga tushmaydi.
- ✅ Demo bola profili allaqachon bog'langan ("demo child", oila kodi `31995`).
- ✅ Login **haqiqatan tekshirildi** (2026-08-18, `POST /api/auth/login` orqali,
  200 OK, token qaytdi).

**"Учетные данные"** bo'limida tanlang: **"Все функции доступны без особых
ограничений"**, keyin yuqoridagi email/parolni kiriting. Qo'shimcha
ko'rsatma matni:

```
This is the PARENT app of the Parvoz family-safety ecosystem. Log in with
the demo account above. On first login you will see the demo child ("demo
child") already linked — this lets you explore all parent-side features
(dashboard, location map, messaging, restrictions, reports) without needing
to pair a real child device. No additional setup is required.
```

---

## 3) Sezgir ruxsatlar — HAQIQIY manifest asosida (2026-08-18 tekshirilgan)

Growth'дан farqli, bu ilova **ancha sodda** — og'ir sezgir ruxsatlar
(background location, QUERY_ALL_PACKAGES, Usage Stats, Device Admin) **YO'Q**,
chunki ular faqat bola qurilmasida ishlaydi.

### Manifestdagi haqiqiy ruxsatlar:

| Ruxsat | Maqsad | Deklaratsiya kerakmi? |
|---|---|---|
| `CAMERA` | Farzandga foto/video xabar yuborish, QR skanerlash | Yo'q (oddiy) |
| `RECORD_AUDIO` | Ovozli xabar yuborish | Yo'q (oddiy) |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | **Faqat FONSIZ** — ota-onaning o'z joylashuvi, xaritada "mening joylashuvim" tugmasi bosilganda | Yo'q — ⚠️ background emas, alohida deklaratsiya SHART EMAS |
| `POST_NOTIFICATIONS` | Push xabar (SOS, xabar, hisobot) | Yo'q |
| `READ_EXTERNAL_STORAGE` (maxSdk 32), `WRITE_EXTERNAL_STORAGE` (maxSdk 29) | Eski Android versiyalarda fayl tanlash | Yo'q |

### ATAYLAB OLIB TASHLANGAN (muhim — Growth'da yo'q narsalar):
- ❌ `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO` —
  `tools:node="remove"`, chunki `image_picker` tizim tanlagichi (Android
  Photo Picker) ishlatiladi, alohida ruxsat kerak emas (2026-08-14 Play
  talabiga javoban olib tashlangan).
- ❌ `AD_ID` / `ACCESS_ADSERVICES_AD_ID` / `ACCESS_ADSERVICES_ATTRIBUTION` —
  ataylab olib tashlangan (reklama yo'q, Data Safety'ni soddalashtiradi).
- ❌ `ACCESS_BACKGROUND_LOCATION` — umuman yo'q.
- ❌ `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS` — umuman yo'q.
- ❌ Device Admin — umuman yo'q.

**Xulosa: "Важные разрешения для приложения" bo'limida deklaratsiya
so'raladigan hech narsa YO'Q** (bu bo'lim faqat background location,
QUERY_ALL_PACKAGES, foreground service special-use, full-screen intent kabi
narsalar uchun — bularning hech biri bu ilovada yo'q).

---

## 4) App content — MAJBURIY bo'limlar

### 4.1 Privacy policy
```
https://farzandimedu.uz/privacy.html
```
2026-08-14da ota-ona ilovasiga tegishli 3 ta yozilmagan funksiya (o'z
joylashuv, ovoz/video xabar, obuna holati) ilova ichidagi matnga qo'shilgan
(`Farzandim/lib/features/legal/data/legal_text.dart`). Saytdagi umumiy
siyosat ikkala ilovani ham qamraydi.

### 4.2 Target audience and content
- Yosh guruhlari: **18+** (bu — ota-ona ilovasi, bolalar to'g'ridan-to'g'ri
  ishlatmaydi) + agar so'ralsa, umumiy ekotizim bolalarga aloqador bo'lgani
  uchun tegishli kichik guruhlarni ham belgilash mumkin — lekin ustuvor
  javob: **bu ilova ota-onalar uchun**.
- "Is your app designed for children?" → **Yo'q** (foydalanuvchisi —
  kattalar; bolalar bilan bog'liq ma'lumot ko'rsatadi, lekin ilovani bola
  ishlatmaydi).

### 4.3 Ads
→ **Yo'q** (`AD_ID` olib tashlangan, reklama kutubxonasi yo'q).

### 4.4 Data safety

**Umumiy:**
- Uchinchi tomonga uzatiladimi? → **Yo'q**
- Shifrlanadimi? → **Ha** (HTTPS/WSS)
- O'chirishni so'rash mumkinmi? → **Ha** (`https://farzandimedu.uz/account-deletion.html`)

**Ma'lumot turlari:**

| Tur | Yig'iladi | Ulashiladi | Majburiy | Maqsad |
|---|---|---|---|---|
| **Ism** | Ha | Yo'q | Ha | Akkaunt boshqaruvi |
| **Email/telefon** | Ha | Yo'q | Ha | Akkaunt boshqaruvi, login |
| **Joylashuv (aniq)** | Ha | Yo'q | Yo'q | Ilova funksionalligi — faqat foydalanuvchi tugma bosganda (fonsiz) |
| **Foto** | Ha | Yo'q | Yo'q | Avatar, chat rasm |
| **Ovoz/audio** | Ha | Yo'q | Yo'q | Ovozli xabar |
| **Video** | Ha | Yo'q | Yo'q | Video xabar |
| **To'lov ma'lumotlari** | Yo'q | Yo'q | — | Karta ma'lumotlari saqlanmaydi (to'lov provayder tomonida) |

> ⚠️ Growth'дан farqli — bu yerda **"Ilova faolligi"**, **"Qurilma
> identifikatori (usage/tracking uchun)"**, **"Sog'liq/fitnes"** deklaratsiya
> qilinmaydi, chunki bu ma'lumotlarni ota-ona ilovasi **yig'maydi**, faqat
> **ko'rsatadi** (bola ilovasidan backend orqali keladi). Faqat "Qurilma ID
> (push xabar uchun, FCM token)" ni belgilashingiz mumkin, ixtiyoriy.

### 4.5 Content rating
Halol to'ldiring: zo'ravonlik/seks/alkogol/qimor YO'Q. Foydalanuvchi kontenti
— faqat ota-ona↔bola orasidagi shaxsiy xabar (ochiq emas). Kutilgan natija:
**Everyone / 3+** (yoki "Teen" agar joylashuv ma'lumoti uchun yuqoriroq
belgilansa — odatda bu turdagi ilovalar uchun ham 3+/Everyone chiqadi).

### 4.6 Government apps → Yo'q
### 4.7 Financial features
Ilovada **obuna ko'rsatiladi va Click orqali to'lov qilinadi** — shuning
uchun bu bo'limda **"Мобильные платежи"** yoki mos variantni belgilash
kerak bo'lishi mumkin (Growth'да "Yo'q" edi, bu yerda **Ha**, chunki
haqiqiy to'lov oqimi bор). Ehtiyot bo'ling — bu Play Billing tekshiruvi
bilan bog'liq (yuqoridagi 0-bo'limdagi qoldiq xavf).

---

## 5) Store listing (ilova sahifasi)

### Tayyor:
- ✅ **Ikon 512×512** — `C:\Users\user\Desktop\play-assets-parent\icon-512.png`
  (`web/icons/Icon-512.png`дан olingan, tasdiqlangan o'lcham)

### Tayyor emas — yaratish kerak:
- ❌ **Feature graphic 1024×500** — Growth'нинг feature graphic'ini
  ISHLATMANG (u audiokitob/videodars haqida, Parents'ga mos emas). Yangi
  matn: joylashuv/xavfsizlik/aloqa mavzusida.
- ❌ **Telefon skrinshotlari** (kamida 2, tavsiya 4-8) — ilovadan haqiqiy
  skrinshot kerak: Dashboard, Xarita/joylashuv, Xabarlar, Cheklovlar/
  Hisobotlar.
- ❌ **Qisqa tavsif** (80 belgi) va **to'liq tavsif** (4000 belgi)

### Tavsif yozishda ⚠️ (Growth'дагidek):
"kuzatuv", "josuslik", "monitoring" so'zlaridan qoching. O'rniga: "oilaviy
xavfsizlik", "farzandingiz bilan aloqa", "joylashuvni ko'rish", "ekran
vaqti hisoboti". Ilovaning ota-ona TOMONI ekanini aniq yozing — bolaning
qurilmasiga alohida "Parvoz Growth" o'rnatilishi kerakligini eslating.

**Kategoriya:** Parenting (yoki Lifestyle / Tools — "Родительский контроль"
Growth'да ishlatilgan, bu yerda ham mos).

---

## 6) Yuborishdan oldin oxirgi tekshiruv

- [ ] AAB build qilindi (workflow ishga tushirilgan, artifact olindi)
- [ ] Play Console'ga yuklandi (Закрытое tekshiruv YOKI to'g'ridan-to'g'ri Production)
- [ ] App access — demo login (`demoparvoz@gmail.com` / `PlayReview2026!`) + ko'rsatma matni kiritildi
- [ ] Data Safety to'ldirildi (yuqoridagi jadval asosida)
- [ ] Content rating anketasi tugallangan
- [ ] Target audience = 18+ (yoki mos javob)
- [ ] Privacy policy URL kiritilgan
- [ ] Financial features — to'lov funksiyasi to'g'ri belgilangan
- [ ] Feature graphic (1024×500) yaratildi va yuklandi
- [ ] Kamida 2 ta haqiqiy skrinshot yuklandi
- [ ] Qisqa + to'liq tavsif yozildi
- [ ] Kategoriya tanlandi
- [ ] **"Отправить на проверку"** bosildi

---

## 7) Agar rad etilsa

Eng ehtimolli sabab — **Play Billing / Payments siyosati** (0-bo'limdagi
qoldiq xavf). Agar shu sabab bilan rad etilsa:

1. `Farzandim/lib/features/settings/presentation/screens/parvoz_premium_screen.dart`
   ichida `kAndroidExternalCheckoutEnabled = true` → `false` qiling
2. Yangi AAB build qiling (workflow orqali)
3. Qayta yuklab, qayta yuboring

Boshqa har qanday rad sababi bo'lsa — xato matnini to'liq nusxalab bering,
birga tahlil qilamiz (Growth'да qilganimizdek).
