# Google Play — "Parvoz Growth" (bola ilovasi) chiqarish qo'llanmasi

> **Maqsad: rad etilmaslik.** Quyidagilar Play Console'da AYNAN shunday
> to'ldirilishi kerak. Noto'g'ri yoki yetishmagan javob = rad etish.
>
> Paket: `com.farzandim.growth` · Nom: **Parvoz Growth**
> (`com.farzandim.child` Play'da band bo'lib chiqdi — shuning uchun
> `applicationId` `growth`ga o'zgartirildi. iOS bundle ID tegilmadi.)
> Maxfiylik siyosati: `https://farzandimedu.uz/privacy.html`

---

## 0) AAB faylni olish

GitHub → **Actions** → **"Build child AAB (Play Market)"** → **Run workflow**
→ tugagach **Artifacts** → `child-release-aab` → ichida `app-release.aab`.

Har yangi yuklashda workflow qayta ishga tushiriladi (versionCode avtomatik
o'sadi — Play buni talab qiladi).

**Birinchi navbatda `Internal testing` trekiga yuklang** — tez tasdiqlanadi,
hamma narsa ishlashini tekshirasiz. Keyin Production.

---

## 1) App content — MAJBURIY bo'limlar

### 1.1 Privacy policy
```
https://farzandimedu.uz/privacy.html
```

### 1.2 Target audience and content (Maqsadli auditoriya)
- Yosh guruhlari: **6–8, 9–12, 13–15, 16–17** va **18+** (ota-ona ham
  ishlatadi) — ilova bolalar VA kattalar uchun.
- "Is your app designed for children?" → **Ha** (bolalar ham maqsadli).
- ⚠️ Bu javob **Families siyosatini** yoqadi — quyidagi hamma narsa majburiy
  bo'ladi (reklama yo'q, rozilik bor, maxfiylik siyosati bor — bizda hammasi bor).

### 1.3 Ads (Reklama)
- "Does your app contain ads?" → **Yo'q** (ilovada reklama yo'q).

### 1.4 Data safety (Ma'lumot xavfsizligi) — ENG MUHIM

**Umumiy:**
- Ma'lumot uchinchi tomonlarga uzatiladimi? → **Yo'q** (faqat o'z serverimiz).
- Ma'lumot uzatishda shifrlanadimi? → **Ha** (HTTPS/WSS).
- Foydalanuvchi o'chirishni so'ray oladimi? → **Ha**, lekin USUL to'g'ri
  ko'rsatilsin (2026-08-18 tuzatish): BOLA ilovasida (com.farzandim.growth)
  akkaunt o'chirish ekrani YO'Q va "Akkaunt yaratadimi?" savoliga **Yo'q**
  deb javob berilsin — akkauntni ota-ona o'z ilovasida yaratadi, bola faqat
  oila kodi bilan ulanadi. O'chirish yo'llari: veb-havola
  https://farzandimedu.uz/account-deletion.html + ota-ona ilovasi
  (DELETE /children/:id kaskadi va "Hisobni butunlay o'chirish").
  OTA-ONA ilovasida (com.farzandim.parent) esa in-app o'chirish BOR
  (Sozlamalar → Hisobni butunlay o'chirish) — u yerda "Ha, ilovada" to'g'ri.
  ⚠️ Agar bola ilovasi uchun "ilovada o'chirish bor" deb belgilansa —
  reviewer topa olmaydi va Data Safety noto'g'riligi uchun rad etadi.

**Yig'iladigan ma'lumot turlari (hammasini belgilang):**

| Tur | Yig'iladi | Ulashiladi | Majburiy | Maqsad |
|---|---|---|---|---|
| **Joylashuv (aniq)** | Ha | Yo'q | Ha | Ilova funksionalligi (ota-onaga bola xavfsizligi) |
| **Ism** | Ha | Yo'q | Ha | Ilova funksionalligi, Akkaunt boshqaruvi |
| **Telefon raqami** | Ha | Yo'q | Yo'q | Akkaunt boshqaruvi (ota-ona kiritadi) |
| **Foto** | Ha | Yo'q | Yo'q | Ilova funksionalligi (avatar, xabar) |
| **Ovoz/audio** | Ha | Yo'q | Yo'q | Ilova funksionalligi (ovozli xabar) |
| **Video** | Ha | Yo'q | Yo'q | Ilova funksionalligi (video xabar) |
| **Ilova faolligi** (o'rnatilgan ilovalar, ekran vaqti) | Ha | Yo'q | Ha | Ilova funksionalligi (ota-ona nazorati) |
| **Qurilma ID** | Ha | Yo'q | Ha | Ilova funksionalligi (push xabar) |
| **Sog'liq/fitnes** (qadamlar) | Ha | Yo'q | Yo'q | Ilova funksionalligi (gamifikatsiya) |

> ⚠️ **Muhim:** "Ulashiladi" hammasida **Yo'q** — ma'lumot faqat bolaning
> o'z ota-onasiga ko'rinadi, bu Play tilida "ulashish" emas.

### 1.5 Content rating (Kontent reytingi)
Anketani halol to'ldiring — bu ilovada zo'ravonlik, seks, alkogol, qimor
YO'Q. Foydalanuvchi kontenti: **ovozli/video xabar faqat ota-ona↔bola
orasida** (ochiq ijtimoiy tarmoq emas). Natija: **Everyone / 3+**.

### 1.6 Government apps → Yo'q
### 1.7 Financial features → Yo'q (to'lov ota-ona ilovasida)

---

## 2) Sezgir ruxsatlar — DEKLARATSIYA matnlari

Play Console → App content → **Sensitive app permissions**. Har biriga
quyidagi matnni yozing (o'zbekcha yoki inglizcha; ingliz tavsiya etiladi).

### 2.1 Background location (`ACCESS_BACKGROUND_LOCATION`) ⚠️ video kerak

**Nima uchun:**
> Parvoz is a parental control app. Parents use it to see their child's
> location for safety. The child device must report location while the app
> is in the background, otherwise the parent cannot know where the child is
> during an emergency (the SOS button also sends the current location).
> Background location is core to the app's primary purpose — child safety.
> The child's parent explicitly consents on first launch, and only the
> linked parent can see the location.

**Video (majburiy):** ekran yozuvi — (1) ota-ona ilovada bolani qo'shadi,
(2) bola ilovasi ruxsat so'raydi va foydalanuvchi "Always allow" beradi,
(3) ota-ona xaritada bolaning joylashuvini ko'radi. YouTube'ga (unlisted)
yuklab, havolasini bering.

### 2.2 All files / QUERY_ALL_PACKAGES ⚠️ eng qattiq

**Nima uchun:**
> Parvoz is a parental control (device management) app. To let parents block
> or time-limit specific apps on the child's device, the app must enumerate
> the apps installed on that device and detect which app is in the
> foreground. Without the full package list the parent cannot choose which
> apps to restrict, which is the app's core advertised feature. The list is
> shown only to the child's own parent and is never shared with third
> parties.

### 2.3 SYSTEM_ALERT_WINDOW (overlay)

**Nima uchun:**
> When a parent blocks an app or the daily time limit is reached, Parvoz
> shows a full-screen overlay on the child's device explaining that the app
> is restricted and offering a "request unlock" button. The overlay is only
> displayed for apps the parent explicitly restricted.

### 2.4 PACKAGE_USAGE_STATS (Usage access)

**Nima uchun:**
> Screen-time reports for parents: which apps the child used and for how
> long. Enabled by the user manually in system settings during onboarding.

---

## 3) Families siyosati — biz mos kelamizmi? (tekshirilgan)

| Talab | Holat |
|---|---|
| Reklama yo'q (yoki Families-approved) | ✅ Reklama umuman yo'q |
| Ota-ona oshkor roziligi (birinchi ochilishda) | ✅ Consent ekrani bor (3 tilda) |
| Maxfiylik siyosati (ochiq URL) | ✅ farzandimedu.uz/privacy.html |
| AccessibilityService ishlatilmaydi | ✅ Yo'q |
| SMS / Qo'ng'iroqlar tarixi / Kontaktlar ruxsati yo'q | ✅ Yo'q |
| SIM/telefon raqamini avtomatik o'qish yo'q | ✅ OLIB TASHLANDI (READ_PHONE_*) |
| `allowBackup=false` | ✅ |
| Ma'lumot shifrlangan kanal (HTTPS/WSS) | ✅ |
| 90 kundan eski xom ma'lumot o'chiriladi | ✅ Retention cron (backend) |
| targetSdk 35 | ✅ |

---

## 4) Store listing (ilova sahifasi)

**Kerak bo'ladi:**
- Ilova nomi (30 belgigacha): `Parvoz Growth`
- Qisqa tavsif (80 belgi), to'liq tavsif (4000 belgi)
- Ilova ikonasi 512×512 PNG
- Feature graphic 1024×500
- Kamida 2 ta telefon skrinshoti (tavsiya: 4–8 ta)
- Kategoriya: **Parenting** (yoki Education)

**Tavsif yozishda ⚠️ (2026-08-18 TUZATILDI):** avvalgi "monitoring
so'zlaridan qoching" maslahati bola ilovasi uchun siyosatga ZID edi.
Play "Monitoring apps" siyosati (answer/12955211) monitoring
funksiyalarini listing'da OSHKORA yozishni TALAB qiladi — yashirish rad
sababi bo'ladi (ilova manifestida `isMonitoringTool=child_monitoring`
deklaratsiyasi bor, listing unga mos bo'lishi shart). Qochish kerak
bo'lgani faqat: "josuslik", "yashirin", "maxfiy", "sezdirmasdan" uslubi.
To'g'ri ohang: "ota-ona nazorati", "joylashuvni ota-onaga yuboradi",
"bola doimiy bildirishnoma orqali biladi". Console matni uchun YAGONA
manba — farzandim_child/PLAY_STORE_LISTING_CHILD.md.

**Ilovaning ikki qismi borligini tavsifda aniq yozing:** bu ilova
ota-onaning "Parvoz" ilovasi bilan birga ishlaydi va bolaning qurilmasiga
ota-ona roziligi bilan o'rnatiladi.

---

## 5) Yuborishdan oldin oxirgi tekshiruv

- [ ] AAB yuklandi (Internal testing)
- [ ] Privacy policy URL kiritilgan
- [ ] Data safety to'liq
- [ ] Content rating anketasi tugallangan
- [ ] Target audience = bolalar (Families)
- [ ] Background location deklaratsiyasi + video havolasi
- [ ] QUERY_ALL_PACKAGES deklaratsiyasi
- [ ] Listing (ikon, grafika, skrinshot, tavsif)
- [ ] Test qurilmada consent ekrani chiqishi tekshirildi
