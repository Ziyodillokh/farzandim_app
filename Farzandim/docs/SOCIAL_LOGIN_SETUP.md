# Ijtimoiy login (Google + Apple) — sozlash qo'llanmasi

Kod tomonida hammasi tayyor: backend endpoint'lar, Flutter UI tugmalari, Prisma model. Endi haqiqiy ishlatib bo'lishi uchun **siz** OAuth credential'larini olishingiz va `.env` + `index.html`'ga qo'yishingiz kerak.

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
| **Android** | Package name: `com.farzandim.app` (yoki AndroidManifest'dagi). SHA-1 fingerprint: `cd android && ./gradlew signingReport` chiqishidan ko'chiring. |
| **iOS** | Bundle ID: `com.farzandim.app`. |

Har birining `Client ID`'ni nusxa oling.

### 3) Backend `.env`'ga qo'shing

```env
GOOGLE_CLIENT_IDS=WEB_ID.apps.googleusercontent.com,ANDROID_ID.apps.googleusercontent.com,IOS_ID.apps.googleusercontent.com
```

Backend `aud` (audience)'ni shu ro'yxat bo'yicha tekshiradi — qaysi platform'dan kelgan token kelishidan qat'i nazar to'g'ri ishlaydi.

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
