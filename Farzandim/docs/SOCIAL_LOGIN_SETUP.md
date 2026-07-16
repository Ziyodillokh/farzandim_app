# Ijtimoiy login (Google + Apple) — sozlash qo'llanmasi

Kod tomonida hammasi tayyor: backend endpoint'lar, Flutter UI tugmalari, Prisma model. Endi haqiqiy ishlatib bo'lishi uchun **siz** OAuth credential'larini olishingiz va `.env` + `index.html`'ga qo'yishingiz kerak.

---

## ⚡ HOZIRGI HOLAT (2026-07-16) — Google uchun qiladigan YAGONA ish

Kod, web va backend allaqachon **"Parvoz" GCP loyihasiga** (`931495868029`) sozlangan va bir xil:

| Joy | Qiymat |
|---|---|
| Android `serverClientId` | `931495868029-b7keq7og9afennh7h3smfaunlf34tsuh.apps.googleusercontent.com` |
| `web/index.html` meta | ayni shu |
| Prod `.env` `GOOGLE_CLIENT_IDS` | ayni shu (2026-07-16 da tuzatildi — avval eski loyiha + kesilgan qiymat edi) |

**Qolgan yagona qadam** — Google Cloud Console → loyiha **Parvoz** (`931495868029`) → *APIs & Services → Credentials → Create Credentials → OAuth client ID → Android*:

```
Package name:  com.farzandim.parent
SHA-1:         F0:E5:65:42:7E:87:7E:78:B2:E6:00:6E:65:86:39:D5:41:25:8C:E3
```

Busiz ilovada `PlatformException(sign_in_failed, ..., 10, ...)` chiqadi — **10 = DEVELOPER_ERROR**, ya'ni "bu paket+SHA-1 ushbu loyihada ro'yxatdan o'tmagan".

SHA-1 qayerdan: bu **release keystore** (CI siri `ANDROID_SIGNING_B64`) — serverga chiqadigan `farzandim-parent.apk` shu bilan imzolangan (`O=Farzandim, CN=Farzandim`, 2053-yilgacha). Har build bir xil imzo, ya'ni bu qiymat o'zgarmaydi. SHA-1 sir emas — har qanday o'rnatilgan APK'dan o'qib olsa bo'ladi.

> **Eslatma:** OAuth consent screen hali **Testing** rejimida — faqat "Test users" ro'yxatidagi akkauntlar kira oladi. Boshqa akkaunt `403 access_denied` beradi (bu xato 10 dan boshqa narsa). Hammaga ochish uchun consent screen'ni **Publish** qiling.

> **Bola ilovasida Google kirish YO'Q** — faqat ota-onada. `com.farzandim.child` uchun OAuth client kerak emas.

---

## Google Sign In (bepul)

### 1) Google Cloud Console'da loyiha yarating

1. https://console.cloud.google.com → New Project → nomi `Farzandim`
2. **APIs & Services → OAuth consent screen**:
   - User Type: **External**
   - App name: `Farzandim`, support email: o'zingizniki
   - Scopes: `openid`, `email`, `profile` (qo'shimcha kerak emas)
   - Test users: dastlab o'zingizni qo'shing (production'gacha)

### 2) 3 ta OAuth Client ID yarating

**APIs & Services → Credentials → Create Credentials → OAuth client ID**:

| Platform | Sozlama |
|---|---|
| **Web application** | Authorized JavaScript origins: `https://farzandimedu.uz`, `http://localhost:5173`, `http://localhost:8081` (Flutter web). Redirect URI kerak emas (frontend SDK). |
| **Android** | Package name: **`com.farzandim.parent`** (ota-ona ilovasi — `android/app/build.gradle.kts` dagi `applicationId`). SHA-1: yuqoridagi release qiymat, yoki debug uchun `cd android && ./gradlew signingReport`. |
| **iOS** | Bundle ID: `com.farzandim.parent`. |

> ⚠️ Paket nomi AYNAN mos bo'lishi shart. Bu jadvalda avval `com.farzandim.app` yozilgan edi — bunday paket loyihada YO'Q, va u bilan ro'yxatdan o'tkazilsa Google xato 10 (DEVELOPER_ERROR) beradi.

Har birining `Client ID`'ni nusxa oling.

### 3) Backend `.env`'ga qo'shing

```env
GOOGLE_CLIENT_IDS=WEB_ID.apps.googleusercontent.com,ANDROID_ID.apps.googleusercontent.com,IOS_ID.apps.googleusercontent.com
```

Backend `aud` (audience)'ni shu ro'yxat bo'yicha tekshiradi — qaysi platform'dan kelgan token kelishidan qat'i nazar to'g'ri ishlaydi.

Amalda Android/iOS uchun **faqat WEB Client ID** yetadi: kod `serverClientId` sifatida shuni beradi, ya'ni idToken'ning `aud`'i doim Web Client ID bo'ladi.

> ⚠️ **PROD .env QO'LDA YANGILANADI.** Deploy `.env`ni `--exclude` qiladi, shuning uchun bu yerni o'zgartirsangiz **serverda ham qo'lda** o'zgartiring:
> ```
> ssh farzandim@95.182.118.39
> cd ~/new-platform/backend && nano .env
> sudo systemctl restart farzandim-v2-backend.service
> ```
> 2026-07-16 gacha prod'da AYNAN shu sabab eski loyihaning ID'si turgan va u yarmida kesilgan edi (`...apps.goog`) → Google kirish hech qachon ishlamagan. Qiymat `.apps.googleusercontent.com` bilan tugashini tekshiring.

### 4) Flutter Web — `web/index.html`'ga qo'shing

Allaqachon placeholder bor:

```html
<meta name="google-signin-client_id" content="__GOOGLE_CLIENT_ID__.apps.googleusercontent.com">
```

`__GOOGLE_CLIENT_ID__` o'rniga **WEB** Client ID'ni qo'ying.

### 5) Flutter Android — `google-services.json`

Agar Firebase loyihangiz bo'lsa, Google Cloud Console'dagi loyihangizni Firebase bilan bog'lang → `google-services.json` yuklab oling → `android/app/` ichiga qo'ying.

Firebase'siz: `google_sign_in` paketi `applicationId`'ni o'qiydi va Android Client ID'ni avtomatik topadi (yuqorida SHA-1 berganmiz).

### 6) Flutter iOS — `Info.plist`

`ios/Runner/Info.plist`'ga qo'shing:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- REVERSED_CLIENT_ID Google Cloud Console iOS client ichida -->
      <string>com.googleusercontent.apps.IOS_ID</string>
    </array>
  </dict>
</array>
```

---

## Apple Sign In ($99/yil Apple Developer)

### 1) App ID + Service ID

1. https://developer.apple.com/account → Certificates, Identifiers & Profiles
2. **Identifiers → +** → **App IDs**:
   - Bundle ID: `com.farzandim.app`
   - Capabilities → **Sign In with Apple** ☑
3. **Identifiers → +** → **Services IDs** (web/Android uchun):
   - Identifier: `com.farzandim.web`
   - Sign In with Apple ☑ → Configure:
     - Primary App ID: yuqoridagi `com.farzandim.app`
     - Domains: `farzandimedu.uz`
     - Return URLs: `https://farzandimedu.uz/auth/apple/callback`

### 2) Key (Sign In with Apple uchun .p8)

**Keys → +** → Sign In with Apple ☑ → Configure → Primary App ID tanlang → Continue → Register → **`.p8` faylni yuklab oling** (bir martalik!).

Saqlash kerak: Key ID, Team ID (sahifaning yuqori o'ng burchagida), Service ID.

### 3) Backend `.env`'ga qo'shing

```env
APPLE_BUNDLE_ID=com.farzandim.app
APPLE_SERVICE_ID=com.farzandim.web
```

> **Eslatma:** Hozirgi backend faqat **ID token verify** qiladi — `.p8` kalit serverda kerak emas (kalit `client_secret` JWT yasash uchun, faqat Apple OAuth `code` flow'da kerak). Bizning flow `idToken` to'g'ridan-to'g'ri client'dan keladi.

### 4) Flutter iOS

`ios/Runner/Runner.entitlements` (yo'q bo'lsa yarating):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.applesignin</key>
  <array>
    <string>Default</string>
  </array>
</dict>
</plist>
```

Xcode'da Signing & Capabilities → "+ Capability" → **Sign In with Apple**.

### 5) Flutter Android — kod tomonida

Apple Android'da OAuth redirect orqali ishlaydi. `signInWithApple()` chaqiruvida `serviceId` va `redirectUri` uzating:

```dart
final err = await ref.read(backendAuthProvider.notifier).signInWithApple(
  serviceId: 'com.farzandim.web',
  redirectUri: 'https://farzandimedu.uz/auth/apple/callback',
);
```

Hozir sign_up_screen'da bu qiymatlar uzatilmagan — Android'da Apple ishlamaydi. iOS'da ishlaydi. Kerak bo'lsa default qiymatlarni `provider`'ga env'dan o'qib qo'sha olamiz.

---

## Sinash

### Backend tekshirish

```powershell
# Server sozlanmaganda 401 qaytaradi:
Invoke-WebRequest -Uri http://127.0.0.1:3000/api/auth/google -Method POST `
  -ContentType 'application/json' -Body '{"idToken":"dummy"}'
# → 401 "Google Sign In sozlanmagan"

# Real token bilan:
Invoke-WebRequest -Uri http://127.0.0.1:3000/api/auth/google -Method POST `
  -ContentType 'application/json' -Body '{"idToken":"<real-google-token>"}'
# → 200 { accessToken, refreshToken, user }
```

### Flutter web tekshirish

1. `.env`'ga `GOOGLE_CLIENT_IDS=...` qo'shing → backend restart
2. `web/index.html`'da `__GOOGLE_CLIENT_ID__` → real WEB ID'ga almashtiring
3. `flutter run -d chrome` → Sign Up sahifa → Google tugmasi
4. Google popup ochilishi va kirgandan keyin dashboard'ga o'tishi kerak

### Foydalanuvchi DB'da qanday saqlanadi

```
users:
  id              = uuid
  role            = PARENT
  email           = foydalanuvchi@gmail.com  (Google'dan)
  google_sub      = 1234567890  (Google'ning stabil ID)
  apple_sub       = null
  password_hash   = null  (parol yo'q — social-only)
  name            = "Foydalanuvchi Ismi"
  avatar_url      = https://lh3.googleusercontent.com/...
```

Email bilan ham, telefon bilan ham, Google bilan ham bir xil akkauntga kirish: email mos kelsa, `google_sub` mavjud akkauntga bog'lanadi (email_verified bo'lsa).
