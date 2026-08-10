# MacBook'ga o'tish — to'liq holat hujjati (2026-08-08)

> Bu hujjat Windows'dagi ish sessiyasidan MacBook'ga o'tish uchun yozilgan.
> Maqsad: **Parvoz Parents (iOS) ilovasini App Store'ga chiqarish**.
> Kod tomoni TUGALLANGAN — qolgani faqat Mac/Xcode/Console ishlari.

---

## 1. Loyiha tuzilishi

| Papka | Nima | Deploy |
|---|---|---|
| `Farzandim/` | **Ota-ona ilovasi** (Parvoz Parents, Flutter) | Play Store (14-kunlik testda) + **iOS: shu ish** |
| `farzandim_child/` | Bola ilovasi (Parvoz Growth, Flutter) | Play Store (audit jarayonida) |
| `backend/` | NestJS + Prisma/Postgres | systemd `farzandim-v2-backend`, port 3100 |
| `admin-web/` | Next.js admin panel | pm2 `v2-admin`, port 3101 |
| `parvoz-landing/parvoz-family-wing/` | Landing (ALOHIDA git repo, ichma-ich) | farzandimedu.uz |

Prod domen: **farzandimedu.uz** (server 95.182.118.39).
Backend va admin `main`ga push qilinganda **GitHub Actions orqali avtomatik deploy** bo'ladi.

### Bundle / package identifikatorlar

| Nima | Qiymat |
|---|---|
| iOS parent (**yangi**) | `uz.parvoz.parent` |
| Android parent | `com.farzandim.parent` (o'zgarmagan, mustaqil) |
| Android child | `com.farzandim.growth` |

> iOS va Android bundle id'larining har xilligi **normal** — ular ikki mustaqil
> ekotizim, hech qayerda taqqoslanmaydi.

---

## 2. ⚠️ ENG MUHIM: git'da YO'Q, lekin build uchun SHART fayllar

`git clone` qilganda bu fayllar **kelmaydi** (`.gitignore`da, ataylab — sirli
ma'lumot). Ularni Windows kompyuteridan **qo'lda ko'chirish** kerak
(AirDrop/USB/Google Drive):

### iOS build uchun MAJBURIY (busiz `flutter run` umuman ishlamaydi)
```
Farzandim/lib/firebase_options.dart      ← BUSIZ BUILD YIQILADI (main.dart import qiladi)
Farzandim/assets/env.json                ← ApiKeys.init() o'qiydi (Mapbox va b. kalitlar)
```

### Android build uchun (iOS ishi uchun shart emas, lekin keyin kerak bo'ladi)
```
Farzandim/android/app/google-services.json
Farzandim/android/key.properties
Farzandim/android/app/upload-keystore.jks
farzandim_child/lib/firebase_options.dart
farzandim_child/android/app/google-services.json
farzandim_child/android/key.properties
farzandim_child/android/app/upload-keystore.jks
```

> **DIQQAT:** bu fayllarni hech qachon git'ga commit qilmang — ular ataylab
> `.gitignore`da. Faqat qo'lda ko'chiring.

---

## 3. Kod tomonida NIMA TAYYOR (tegmaslik kerak)

Barchasi `main` branch'da, `flutter analyze` = **0 xato**.

### Apple IAP (App Store Guideline 3.1.1 — hal qilingan)
- `Farzandim/lib/features/settings/data/apple_iap_service.dart` — product ID'lar
- `Farzandim/lib/features/settings/presentation/screens/parvoz_premium_screen.dart`
  — iOS'da StoreKit oqimi (query → buy → purchaseStream → backend verify →
  completePurchase), "Xaridlarni tiklash" tugmasi (Apple majburiy),
  `canceled`/`pending`/`error` handle qilingan
- **Narx StoreKit'dan** olinadi (avval UZS ko'rinib, xarid oynasida USD chiqardi
  — bu Apple 2.3.1 rad sababi edi, tuzatilgan). Android'da hamon so'm (Click).
- `Farzandim/lib/features/settings/data/apple_receipt_sync_service.dart` (**YANGI**)
  — obuna **renewal/expiry** poll'i: `app.dart` root darajasida, har `resume`da
  va sovuq startda iOS lokal kvitansiyasini o'qib backend'ga jim yuboradi
  (App Store Server Notifications webhook o'rniga)
- Backend `POST /payments/apple/verify`
  (`backend/src/modules/payments/apple-iap.service.ts`) — legacy `verifyReceipt`
  + `APPLE_IAP_SHARED_SECRET`, prod→sandbox (21007) fallback, idempotency
  `transaction_id` bo'yicha (`original_transaction_id` EMAS — u har renewal'da
  bir xil qolib, muddat uzaytirilmay qolardi)

### iOS native konfiguratsiya (git'da bor, clone bilan keladi)
- `ios/Runner/Runner.entitlements` — `aps-environment` + `com.apple.developer.applesignin`
- `ios/Runner/PrivacyInfo.xcprivacy` — Apple Privacy Manifest (2024-05 dan majburiy)
- `ios/Runner/Info.plist` — `NSMicrophoneUsageDescription` (busiz ovoz yozishda
  crash), `NSCamera`/`NSPhotoLibrary`/`NSLocationWhenInUse`,
  `ITSAppUsesNonExemptEncryption=false`, `CFBundleURLTypes` (**placeholder** —
  4-bo'limga qarang)
- `ios/Podfile` — `platform :ios, '13.0'`
- `project.pbxproj` — bundle `uz.parvoz.parent`, `TARGETED_DEVICE_FAMILY = 1`
  (faqat iPhone — iPad screenshot shart emas)

### App Store Connect (foydalanuvchi allaqachon qilgan)
- 4 ta auto-renewable obuna yaratilgan va **narxlangan**:
  `parvoz.standard.monthly`, `parvoz.standard.yearly`,
  `parvoz.premium.monthly`, `parvoz.premium.yearly`
- Paid Apps shartnomasi imzolangan
- IAP review skrinshoti yuklangan
- `APPLE_IAP_SHARED_SECRET` server `.env`ga qo'yilgan

---

## 4. QOLGAN ISHLAR (Mac'da bajariladi) — tartib bilan

### A. Muhitni tekshirish
```bash
flutter --version && xcodebuild -version && pod --version && git --version
```
Yo'q bo'lsa: Xcode (App Store), Flutter SDK (flutter.dev), `sudo gem install cocoapods`.

### B. Firebase iOS (push uchun) — 1-BLOKER
1. Firebase Console (loyiha `farzandim-mvp`, raqami **163835260058**) → iOS ilova
   qo'shish, bundle **`uz.parvoz.parent`**
2. `GoogleService-Info.plist` yuklab olib → `Farzandim/ios/Runner/` ichiga
3. Xcode'da Runner target'ga qo'shish ("Add Files to Runner…")
   > Eslatma: `project.pbxproj`da bu faylga **havola allaqachon bor**, lekin
   > faylning o'zi yo'q — eski buzuq referansni olib tashlab, qaytadan qo'shish
   > kerak bo'lishi mumkin.
4. `flutterfire configure --ios-bundle-id=uz.parvoz.parent`
   (`lib/firebase_options.dart` iOS bloki hozir **stub** — shu bilan to'ldiriladi)
5. Firebase Console → Project Settings → Cloud Messaging → **APNs Auth Key
   (.p8)** yuklash (Apple Developer → Keys'da yaratiladi)

### C. Google login (iOS) URL scheme
`ios/Runner/Info.plist` → `CFBundleURLSchemes` hozir **placeholder**:
```
com.googleusercontent.apps.931495868029-b7keq7og9afennh7h3smfaunlf34tsuh
```
Buni `GoogleService-Info.plist` ichidagi haqiqiy **`REVERSED_CLIENT_ID`** bilan
almashtirish kerak. Google Cloud'da (loyiha **931495868029 "Parvoz"**, Firebase
loyihasi EMAS) bundle `uz.parvoz.parent` uchun **iOS OAuth client** bo'lishi shart.
> Sign in with Apple bunga bog'liq emas — u shusiz ham ishlaydi.

### D. Apple Developer + Xcode signing
1. Apple Developer → Identifiers → App ID **`uz.parvoz.parent`**;
   capability'lar: **Push Notifications**, **Sign in with Apple**, **In-App Purchase**
2. Xcode → Runner → Signing & Capabilities → **Team** tanlash
   (`DEVELOPMENT_TEAM` hozir bo'sh — busiz arxiv qurilmaydi)
3. **+ Capability** × 3: Push Notifications, Sign in with Apple, In-App Purchase
   → bu `CODE_SIGN_ENTITLEMENTS`ni **avtomatik** ulaydi (hozir ulanmagan)
4. **PrivacyInfo.xcprivacy** → Build Phases → **Copy Bundle Resources** ro'yxatida
   bo'lishi SHART (aks holda `ITMS-91053` bilan rad etiladi — eng ko'p uchraydigan xato)

### E. Birinchi real build (bu ilova hech qachon iOS'da qurilmagan!)
```bash
cd Farzandim
flutter pub get
cd ios && pod install && cd ..
flutter run          # simulyator yoki qurilma
```
Kutilishi mumkin bo'lgan muammolar: pod versiyalari, signing, minimum iOS
target. Xatolar chiqsa — Claude'ga to'liq matnini bering.

### F. IAP sandbox sinovi
To'liq checklist pastda (6-bo'lim).

### G. App Store Connect — submission aktivlari
- **App Privacy labels** (aniq: joylashuv = Linked / App Functionality,
  "Used for Tracking" **BELGILANMASIN** — aks holda "stalkerware" rad xavfi;
  Firebase Crashlytics/Analytics turlarini ham qo'shish)
- **Demo akkaunt**: ota-ona login/parol + unga **ulangan, ma'lumotli bola**
  (joylashuv tarixi, geo-zona, xabarlar) — bo'sh dashboard = 2.1 rad
- **Review notes**: "ikki tomonlama rozilikka asoslangan oilaviy nazorat,
  yashirin kuzatuv emas; bola ilovasida doimiy bildirishnoma bor" (5.1.2 rad oldini oladi)
- Screenshotlar: 6.9"/6.7" iPhone (iPad shart emas — faqat-iPhone qilingan)
- Privacy Policy URL + Support URL (farzandimedu.uz)
- Yosh reytingi — **Kids Category'ga QO'SHMANG**

### H. Archive → Upload
Xcode → Product → Archive → Distribute App → App Store Connect.

---

## 5. iOS'dan TASHQARI ochiq masalalar

### Google login Android'da ishlamaydi (`ApiException: 10`)
Kod **to'g'ri**. Muammo: Google Cloud loyihasi **931495868029 (Parvoz)** da
`com.farzandim.parent` uchun **Android OAuth client + SHA-1** ro'yxatdan
o'tmagan. (Firebase loyihasi 163835260058 — bu **boshqa** loyiha, u yerda emas!)

Ro'yxatga olinishi kerak bo'lgan SHA-1'lar:
```
Debug:       83:A9:4A:32:3E:41:88:35:0F:E4:B8:53:2D:12:BD:13:10:6C:93:0D
Upload key:  F0:E5:65:42:7E:87:7E:78:B2:E6:00:6E:65:86:39:D5:41:25:8C:E3
Play App Signing:  Play Console → App integrity → App signing key certificate
                   ← Play orqali tarqatilgani uchun ENG MUHIMI shu
```

### Bola ilovasi crash ("Parvoz Growth ishdan chiqdi")
Sabab **aniqlanmagan** (log yo'q edi). Commit `2e31662` bilan **Crashlytics
ulandi** — yangi build chiqarib, crash takrorlansa Firebase Console →
Crashlytics'da aniq stack trace ko'rinadi. Dart error handler'lar allaqachon
bor edi, shuning uchun crash ehtimolan **native (Kotlin)** darajada
(`RestrictionService`, watchdog, `UsageStatsPlugin`).

### Android hali Google Play Billing'da EMAS
Obuna Android'da hamon **Click** (tashqi to'lov) orqali. Bu iOS ishiga
taalluqli emas, lekin Play siyosati uchun kelajakda alohida ish bo'ladi.

---

## 6. Apple IAP — sinov checklist (submission'dan oldin)

### Sozlash
- [ ] App Store Connect'da 4 mahsulot "Ready to Submit"
- [ ] **Sandbox Tester** akkaunt yaratilgan (Users and Access → Sandbox Testers)
      — haqiqiy Apple ID emas, alohida test email
- [ ] Qurilmada Settings → App Store → **Sandbox Account**ga o'sha tester bilan kirilgan

### Xarid
- [ ] "Tariflar" ekranida 4 narx to'g'ri ($ formatida) ko'rinadi
- [ ] Standard oylik xarid → StoreKit oynasi → tasdiqlash → **Standard funksiyalar ochiladi**
- [ ] Premium uchun ham
- [ ] Yillik variant uchun ham

### Restore
- [ ] Ilovani o'chirib qayta o'rnating → "Xaridlarni tiklash" → obuna tiklanadi

### Renewal (bugungi yangi kod)
- [ ] Sandbox'da obuna tez yangilanadi (1 oylik ≈ 5 daqiqa)
- [ ] Ilovani fon → foreground qiling; bir necha sikldan keyin serverda
      `Subscription.expiresAt` **oldinga siljiganini** tekshiring

### Cancel / Expire
- [ ] Sandbox akkauntda obunani bekor qiling → muddat tugagach kirish **yopiladi**
- [ ] Xarid oynasida "Cancel" bosilsa — **xato-toast chiqmasligi** kerak (jim)

### Backend
- [ ] Har verify uchun `Payment` yozuvi: `method='apple'`, `externalId` = `transaction_id`
- [ ] Bitta siklda ilovani bir necha marta ochib-yoping → **takroriy yozuv bo'lmasin** (idempotency)

---

## 7. Ish qoidalari (yangi sessiya uchun)

- **Til:** suhbat va kod izohlari — **o'zbekcha** (lotin)
- **CI gate:** parent ilovada `flutter analyze --fatal-infos` = **0** bo'lishi SHART
  (aks holda deploy bloklanadi)
- **Git:** har push'dan oldin `git pull --rebase --autostash origin main`
  (parallel sessiyalar bor); faqat aniq fayllarni stage qiling
- **Deploy xavfi:** `backend/**` yoki `admin-web/**` push qilinsa —
  **prodga avtomatik deploy** bo'ladi. Ehtiyot bo'ling.
- **Sirlar:** 2-bo'limdagi fayllar hech qachon commit qilinmasin
- Taxmin qilmang — kodni o'qib tasdiqlang

---

## 8. Oxirgi commitlar (kontekst uchun)

```
f2b15de  feat(iap): Apple obuna renewal/expiry handling (app-level receipt poll)
63a27fb  fix(ios): App Store Connect'dagi haqiqiy product ID'larga moslashtirish
2e31662  feat(child): Crashlytics ulash — native crash diagnostikasi
66c9201  fix(ios): paywall narxi endi StoreKit'dan (UZS/USD nomuvofiqligi)
fbf50fb  chore(ios): bundle id com.farzandim.parent -> uz.parvoz.parent
```
