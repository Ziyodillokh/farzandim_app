# Parvoz Growth (bola ilovasi) — iOS App Store'ga chiqarish: qolgan ishlar

> Holat: 2026-10-10 (yangilangan), branch `feat/child-ios` (lokal, push qilinmagan).
> Kod tomoni tayyor: `flutter build ios --release --no-codesign` va
> `flutter build apk` o'tadi, `flutter analyze` toza, testlar o'tadi.
> Quyida faqat **Apple/Firebase akkaunti, Mac + Xcode va real iPhone** talab
> qiladigan ishlar — tartib bo'yicha.

---

## Kodda nima qilindi (qisqacha)

| Bosqich | Natija |
|---|---|
| 1. Build | iOS 16 target, CocoaPods ziddiyati hal qilindi (mobile_scanner 7.4.2), permission_handler makroslari, Privacy manifest, Info.plist ruxsat matnlari en/uz/ru |
| 2. iOS oqimi | `PlatformCapabilities` — platforma farqlari bitta joyda. iOS'da: usage yuborilmaydi, foreground service yo'q, ruxsatlar ekrani bloklamaydi va bir marta chiqadi, qadamlar CoreMotion'dan, fon joylashuvi `AppleSettings`, bildirishnoma ruxsati faqat ruxsatlar ekranida |
| 3. Family Controls | `ScreenTimePlugin.swift` (ruxsat `.child`, ilova tanlash, siyosat), 3 ta kengaytma: `ParvozMonitor` (jadval va qo'shimcha vaqt tugashi), `ParvozShieldConfig` (Parvoz dizaynidagi bloklash ekrani), `ParvozShieldAction` ("Qo'shimcha vaqt so'rash"); "Ekran vaqti" ekrani + ota-ona PIN'i, doimiy himoya (saytlar filtri, o'rnatishni taqiqlash) |
| 4. Do'kon | `farzandim_child/APP_STORE_LISTING_CHILD.md` — tavsif, App Privacy, Age Rating, Review Notes |

Android xatti-harakati o'zgarmagan (faqat QR skaner kutubxonasi yangilangan —
pastdagi 6-bandga qarang).

---

## 1. Apple Developer Portal — ✅ BAJARILDI (2026-10-10)

- App Group `group.uz.parvoz.growth` yaratildi.
- App ID'lar: `uz.parvoz.growth` (Push, App Groups, Family Controls Dev + Distribution),
  `uz.parvoz.growth.monitor`, `.shield`, `.shieldaction`, `.report` (App Groups,
  Family Controls Dev + Distribution).
- Family Controls **Distribution** katagi kengaytmalarda ham belgilandi — ruxsat
  akkauntga biriktirilgan, Apple'ga alohida so'rov **kerak emas**. Yakuniy tasdiq:
  Xcode App Store profilini yaratganda xato bermasa.
- `.report` App ID'si zaxira (ekran vaqti hisoboti keyingi versiyada).

## 2. Firebase — qisman bajarildi

✅ Firebase'da iOS ilova yaratildi: **Parvoz Growth** (`uz.parvoz.growth`,
`1:163835260058:ios:a57b38449e513cafd30323`).
✅ `lib/firebase_options.dart` (iOS qismi) va `ios/Runner/GoogleService-Info.plist`
yangilandi, `firebase.json` ga iOS qo'shildi, Crashlytics dSYM yuklash bosqichi
qo'shildi (ota-ona ilovasidagidek).

⚠️ Ikkala fayl `.gitignore`da — **faqat shu Mac'da bor**. Boshqa kompyuterda
build qilish uchun ularni xavfsiz joyga nusxalang (yoki u yerda
`flutterfire configure` qiling).

❌ **Sizga qoldi — APNs kaliti** (push'siz iOS'da bildirishnoma kelmaydi):
1. `.p8` kalit: Apple portal → **Keys**. Ota-ona ilovasi uchun yaratilgan kalit
   bo'lsa — o'sha `.p8` fayl. Bo'lmasa: `+` → nom `Parvoz APNs` → ✅ Apple Push
   Notifications service (APNs) → Register → **Download** (faqat bir marta!) →
   Key ID'ni yozib oling.
2. console.firebase.google.com → **farzandim-mvp** → ⚙️ Project settings →
   **Cloud Messaging** → Apple app configuration → **Parvoz Growth** →
   APNs Authentication Key → **Upload**: `.p8`, Key ID, Team ID `PLJAB8V75N`.

## 3. Imzolash va App Store build — ✅ BAJARILDI (2026-10-10)

- Jamoada iPhone yo'q edi ("Your team has no devices") — shu Mac (Apple M4 Pro)
  "My Mac (Designed for iPad)" sifatida ro'yxatdan o'tkazildi va 4 ta target uchun
  profillar avtomatik yaratildi.
- `flutter build ipa --release --build-name 1.0.0 --build-number 1` o'tdi →
  `farzandim_child/build/ios/ipa/Parvoz Growth.ipa`. Tekshirildi: 4 ta qism ham
  **Apple Distribution** + App Store profili bilan, hammasida Family Controls va
  App Group, asosiy ilovada `aps-environment = production`.
- Keyingi build'lar uchun build raqamini oshiring: `--build-number 2`, `3`, ...
- Xcode orqali iPhone'ga to'g'ridan-to'g'ri o'rnatish uchun: iPhone'ni ulang,
  Developer Mode'ni yoqing, `flutter run --release -d <iPhone>`. TestFlight
  orqali o'rnatsangiz, kabel kerak emas.

## 4. Real qurilmada sinov (Family Sharing)

Kerak: ota-ona Apple Account'i oilasiga qo'shilgan **bola Apple Account'i**
bilan kirilgan test iPhone (iOS 16+), ota-ona telefonida Parvoz ilovasi.

- [ ] Pairing: oila kodi va QR skaner
- [ ] Ruxsatlar ekrani: har bir ruxsatni rad etib ko'ring — ilova ishlashda
      davom etadi, Sozlamalar faqat qayta bosilganda ochiladi
- [ ] Joylashuv: ilova yopiq paytda ota-ona xaritasida yangilanadimi
- [ ] Qadamlar: statistika ekranida bugungi son iPhone "Health" ilovasidagiga yaqin
- [ ] Push bildirishnoma keladi (2-band bajarilgandan keyin)
- [ ] Sozlamalar → Ekran vaqti → "Ota-ona tasdig'ini olish" → ota-ona Apple ID bilan tasdiqlaydi
- [ ] PIN o'rnatish → ilovalarni tanlash (masalan "Games" toifasi)
- [ ] Ota-ona ilovasida jadval (BLOCK, masalan hozirdan +20 daqiqa) → bola
      ilovasini YOPING → vaqt kelganda tanlangan ilovalar bloklanadi, tugaganda ochiladi
- [ ] Ota-ona "Barcha ilovalarni bloklash"ni yoqadi → bola ilovasi ochilganda/WS
      kelganda tanlangan ilovalar bloklanadi
- [ ] Bloklangan ilova ochilganda **Parvoz dizaynidagi ekran** chiqadi (tanlangan tilda)
- [ ] "Qo'shimcha vaqt so'rash" → eslatma keladi → bosilsa Parvoz ochiladi va
      so'rov oynasi chiqadi → ota-ona ilovasida so'rov ko'rinadi → tasdiqlansa
      ilova ochiladi → vaqt tugagach (ilova yopiq bo'lsa ham) yana bloklanadi
- [ ] Ekran vaqti → Doimiy himoya: "Kattalar saytlari" (Safari'da tekshiring) va
      "Yangi ilova o'rnatishni taqiqlash" (App Store'da o'rnatib ko'ring)
- [ ] Ilovani o'chirib ko'ring — ota-ona ruxsatisiz o'chmasligi kerak (`.child` tasdig'i)
- [ ] **Ekran vaqti oqimini ekran yozuviga oling** — App Review uchun video
      (`APP_STORE_LISTING_CHILD.md` 7-band `<<VIDEO_URL>>`)

## 5. App Store Connect

1. **My Apps → + → New App**: iOS, nom `Parvoz Growth`, bundle `uz.parvoz.growth`,
   asosiy til English (U.S.).
2. Barcha maydonlar: `farzandim_child/APP_STORE_LISTING_CHILD.md` (1–9-bandlar).
   Review Notes'dagi `<<FAMILY_CODE>>`, demo akkaunt va video havolasini to'ldiring.
3. Build:
   ```bash
   cd farzandim_child
   flutter build ipa --release --build-name 1.0.0 --build-number 1
   ```
   (yoki Xcode → Product → Archive). Distribution eksportda
   `aps-environment` avtomatik `production` bo'ladi. Yuklash: Xcode Organizer
   yoki Transporter.
4. TestFlight (internal) → 4-banddagi ro'yxatni TestFlight build'ida qayta tekshiring.
5. Submit for Review.

## 6. Android tomoni uchun eslatma

QR skaner kutubxonasi `mobile_scanner` 5 → 7 ga yangilandi (iOS build uchun
majburiy edi). Android APK yig'iladi, lekin keyingi **Android relizidan oldin**
real telefonda QR orqali ulanish va qayta ulanishni qo'lda sinab ko'ring.

## 7. Ma'lum cheklovlar (topshirishni to'smaydi, keyingi ishlar)

| # | Nima | Qayerda |
|---|---|---|
| 1 | "Barcha ilovalarni bloklash" iOS'da ilova ochilganda / WS kelganda qo'llanadi (fonda so'rov yo'q). Yaxshilash: backend `restrictions_sync` push'ini `content-available: 1` bilan yuborsin | backend |
| 2 | Android'dagi per-ilova kunlik limitlar (AppLimit) iOS'da yo'q (DeviceActivityEvent + ota-ona UI kerak) | keyingi versiya |
| 2a | Bolaning o'z ekran vaqti grafigi (DeviceActivityReport, `.report` App ID tayyor). Ota-ona hozircha o'z iPhone'idagi Sozlamalar → Ekran vaqti'da ko'radi | keyingi versiya |
| 2b | "Qo'shimcha vaqt" so'rovida ilova nomi yo'q (Apple: ilova nomi serverga chiqmaydi) — ota-ona "ekran vaqti" so'rovi sifatida ko'radi | dizayn bo'yicha |
| 3 | "Jonli eshitish" faqat Android — ota-ona ilovasi iOS bolada tugmani yashirishi kerak | ota-ona ilovasi |
| 4 | iOS bolada ota-ona ilovasi Android ruxsat ogohlantirishlarini ko'rsatmasligi kerak (endi bu maydonlar yuborilmaydi — `null`ni to'g'ri ko'rsatishini tekshiring) | ota-ona ilovasi |
| 5 | Push'dagi rasm iOS'da ko'rinmaydi — Notification Service Extension kerak (ikkala ilovada yo'q) | ikkala ilova |
| 6 | Maxfiylik siyosatiga iOS bo'limi — tayyor matn `APP_STORE_LISTING_CHILD.md` 10-bandda | website |
| 7 | Ota-ona PIN'ini unutsa: ota-ona ilovasidan bolani uzib, qayta ulash PIN'ni tozalaydi | — |
