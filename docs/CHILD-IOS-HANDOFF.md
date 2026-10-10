# Parvoz Growth (bola ilovasi) — iOS App Store'ga chiqarish: qolgan ishlar

> Holat: 2026-10-10, branch `feat/child-ios` (lokal, push qilinmagan).
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
| 3. Family Controls | `ScreenTimePlugin.swift` (ruxsat `.child`, ilova tanlash, siyosat), `ParvozMonitor` kengaytmasi (jadval bo'yicha avtomatik yoqish/o'chirish), "Ekran vaqti" ekrani + ota-ona PIN'i, backend jadvali → iOS siyosati |
| 4. Do'kon | `farzandim_child/APP_STORE_LISTING_CHILD.md` — tavsif, App Privacy, Age Rating, Review Notes |

Android xatti-harakati o'zgarmagan (faqat QR skaner kutubxonasi yangilangan —
pastdagi 6-bandga qarang).

---

## 1. Apple Developer Portal (developer.apple.com → Certificates, IDs & Profiles)

1. **App Group** yarating: `group.uz.parvoz.growth`.
2. **App ID `uz.parvoz.growth`** (mavjud) → Capabilities:
   - Push Notifications ✅
   - App Groups ✅ → `group.uz.parvoz.growth`
   - Family Controls ✅ (Distribution — allaqachon tasdiqlangan)
3. **Yangi App ID `uz.parvoz.growth.monitor`** (DeviceActivity kengaytmasi):
   - App Groups ✅ → `group.uz.parvoz.growth`
   - Family Controls ✅
4. ⚠️ **Family Controls Distribution so'rovi kengaytma uchun ham kerak.**
   Apple ruxsatni har bir bundle ID uchun alohida beradi:
   https://developer.apple.com/contact/request/family-controls-distribution
   → `uz.parvoz.growth.monitor` uchun so'rov yuboring (asosiy ilova uchun
   berilgan javobga havola qiling). Tasdiqlanmaguncha TestFlight/App Store
   build'i imzolanmaydi; Development (o'z iPhone'ingizda) ishlayveradi.
5. **APNs kaliti (.p8)** — ota-ona ilovasi uchun yaratilgani shu jamoa
   (`PLJAB8V75N`) uchun umumiy, qayta ishlatsa bo'ladi.

## 2. Firebase (push bildirishnomalar uchun SHART)

Hozir `lib/firebase_options.dart` iOS uchun eski `com.farzandim.child`ga
sozlangan va `GoogleService-Info.plist` yo'q → iOS'da push ishlamaydi.

1. Firebase console → loyiha → **Add app → iOS** → bundle `uz.parvoz.growth`.
2. Project settings → Cloud Messaging → **APNs Authentication Key** (.p8) yuklang.
3. Mac'da:
   ```bash
   cd farzandim_child
   flutterfire configure   # iOS uchun yangi uz.parvoz.growth ilovasini tanlang
   ```
   Tekshiring: `lib/firebase_options.dart` ichida `iosBundleId: 'uz.parvoz.growth'`.
   (Fayl `.gitignore`da — CI/boshqa kompyuterga alohida ko'chiring.)

## 3. Xcode (Mac)

1. `farzandim_child/ios/Runner.xcworkspace`ni oching (`.xcodeproj` emas).
2. **Runner** va **ParvozMonitor** target'lari → Signing & Capabilities →
   Team `PLJAB8V75N`, "Automatically manage signing". Family Controls, App
   Groups (va Runner'da Push) ko'rinishi kerak — entitlements fayllari tayyor.
3. Real iPhone'da ishga tushiring (Family Controls simulyatorda ishlamaydi).

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
| 3 | "Jonli eshitish" faqat Android — ota-ona ilovasi iOS bolada tugmani yashirishi kerak | ota-ona ilovasi |
| 4 | iOS bolada ota-ona ilovasi Android ruxsat ogohlantirishlarini ko'rsatmasligi kerak (endi bu maydonlar yuborilmaydi — `null`ni to'g'ri ko'rsatishini tekshiring) | ota-ona ilovasi |
| 5 | Push'dagi rasm iOS'da ko'rinmaydi — Notification Service Extension kerak (ikkala ilovada yo'q) | ikkala ilova |
| 6 | Maxfiylik siyosatiga iOS bo'limi — tayyor matn `APP_STORE_LISTING_CHILD.md` 10-bandda | website |
| 7 | Ota-ona PIN'ini unutsa: ota-ona ilovasidan bolani uzib, qayta ulash PIN'ni tozalaydi | — |
