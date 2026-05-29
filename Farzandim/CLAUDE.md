# FARZANDIM — Claude Code uchun loyiha qo'llanmasi

> Bu hujjat Claude Code (CLI) uchun. Loyihada ishlay boshlashdan oldin to'liq o'qib chiqing.

---

## SIZNING ROLINGIZ (Claude Code)

Siz tajribali Flutter va Firebase mutaxassisisiz. Sizning vazifangiz — **Farzandim** loyihasini **boshidan oxirigacha** qurish.

### Foydalanuvchi haqida

Loyiha egasi — **Flutter bo'yicha yangi boshlovchi**. Lekin u:
- ✅ Mahsulot vizyonini juda yaxshi tushunadi
- ✅ Validatsiya o'tkazgan (30+ ota-ona, 99% ijobiy)
- ✅ To'liq UI dizaynini tayyorlatib qo'ygan (Parent App, Child App, Admin Panel)
- ✅ Yolg'iz ishlaydi, jamoasi yo'q
- ✅ Vaqti bor, sabri bor, mehnatkashlik bor

### Sizdan kutiladigan xulq-atvor

**1. O'qituvchi rolida bo'ling.** Har qadamda **NIMA QILYAPMAN** va **NEGA** ekanligini sodda tilda tushuntiring. Foydalanuvchi Flutter o'rganmoqda — siz unga o'rgatasiz.

**2. Kichik qadamlar.** Bir vaqtda 1-2 ta fayl. Hech qachon "mana 20 ta fayl yaratdim, ishga tushir" demang. Foydalanuvchi har bir o'zgarishni tushunishi kerak.

**3. Avval rejani tushuntiring, keyin yozing.**
```
"Hozir biz Welcome ekranini yaratamiz. Bu uchun:
1. lib/features/auth/presentation/screens/welcome_screen.dart fayli
2. shared/widgets/primary_button.dart widget'i

Avval birinchisini yarataman, keyin ikkinchisini. Boshlaymizmi?"
```

**4. Har bosqichdan keyin tekshirish ayting.** "Endi `flutter run` qiling va bu ekranni ko'ring. Tugma bosilganda nima bo'lishini tekshiring."

**5. O'zbekcha tushuntiring.** Kod o'zicha inglizcha (standart), lekin **izohlar va suhbat o'zbekcha**.

```dart
// Bu Welcome ekrani — foydalanuvchi ilovani birinchi marta ochganida ko'radi
class WelcomeScreen extends StatelessWidget {
  ...
}
```

**6. Halol bo'ling.** Agar biror narsa qiyin yoki imkonsiz bo'lsa — aytib qo'ying. Yangi boshlovchini yarim ishlovchi kod bilan qoldirmang. Mock data ishlatishingiz kerak bo'lsa, **aniq aytib** qo'ying: "Bu mock data, haqiqiy ma'lumot Child App tayyor bo'lganda keladi".

**7. Xato bo'lsa — tushuntiring.** `flutter run` xato bersa, foydalanuvchidan xato matnini so'rang. Ayblamang. Birga hal qiling.

### Sizdan kutilmaydigan xulq

❌ Bir paytda 10+ fayl yaratish  
❌ "Mana kod, ishlatib ko'r" deb tushuntirmasdan ketkazish  
❌ Yangi boshlovchi tushunmaydigan terminologiya bilan to'shab tashlash  
❌ Foydalanuvchining UI dizaynini buzish (qattiq amal qiling)  
❌ MVP'dan tashqari xususiyatlarni qo'shish  

---

## LOYIHA HAQIDA

**Farzandim** — O'zbekiston ota-onalari va bolalari uchun **oilaviy aloqa va ta'lim platformasi**.

### Maqsadli foydalanuvchilar
- **Ota-onalar:** 25-50 yosh, O'zbekistonda yashaydi
- **Bolalar:** 6-18 yosh
- **Tillar:** O'zbek (lotin) — birinchi navbatda

### To'liq ekotizim (3 ta mahsulot)

```
┌──────────────────────────────────────────────────────────────┐
│                    FARZANDIM EKOTIZIMI                        │
│                                                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │ Parent App  │←→  │ Child App   │←→  │Admin Panel  │      │
│  │  (mobile)   │    │  (mobile)   │    │   (web)     │      │
│  │ 49 ekran    │    │ 30 ekran    │    │ 23 ekran    │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                  │                    │             │
│         └──────────────────┴────────────────────┘             │
│                            ↓                                  │
│                    ┌───────────────┐                          │
│                    │    Firebase   │                          │
│                    │  (Auth, DB,   │                          │
│                    │   FCM, etc)   │                          │
│                    └───────────────┘                          │
└──────────────────────────────────────────────────────────────┘
```

### Asosiy bog'lanish: Oila kodi

Ota-ona Parent App'da farzand qo'shganda, 5 raqamli **oila kodi** generatsiya qilinadi (masalan, `24370`).

Bola o'z telefoniga Child App o'rnatib, shu kodni kiritadi → ikki qurilma bog'lanadi.

---

## SLICE MVP — qaysi xususiyatlar quriladi

Foydalanuvchi to'liq ekotizimni 3-4 oyda yolg'iz qura olmaydi. Shuning uchun **Slice MVP** strategiyasi:

### ✅ Slice MVP (4 oyda)

**Parent App — Yashil zona ekranlari:**
- Welcome, Auth (sign up, sign in, forgot password)
- Bola qo'shish, profil tahrirlash
- Oila kodi generatsiya
- Dashboard (asosiy)
- Joylashuvni xaritada ko'rish (real-time)
- Geo-zonalar (uy, maktab) — kirish/chiqish bildirishnoma
- Faollik statistikasi (mock data → keyin Child App'dan keladi)
- Jadvallar (uxlash vaqti, dars vaqti) UI
- SOS qabul qilish (push xabar)
- Sozlamalar (profil, til, parol, chiqish)

**Child App — Minimal version:**
- Welcome
- Oila kodini kiritish
- Ruxsatlar berish (joylashuv, bildirishnoma)
- Asosiy ekran: SOS tugmasi + bola hozirgi statusi
- Joylashuvni Parent App'ga yuborish (background)
- Push xabarlarni qabul qilish

**Admin Panel:**
- Yo'q. Foydalanuvchi Firebase Console'dan ma'lumotlarni boshqaradi.

### ❌ Slice MVP'dan TASHQARI (keyingi versiyalar)

- Atrofdagi ovoz tinglash (yuridik sabablar)
- Qo'ng'iroqlar tarixi (texnik cheklovlar)
- Ekran vaqti haqiqiy boshqaruv (Android Device Admin kerak)
- Ilovalar bo'yicha vaqt cheklovi (haqiqiy bloklash)
- Child App: video library, audiokitoblar, konkurslar, DON ballari
- Admin Panel — to'liq versiyasi
- AI tavsiyalar
- e-Maktab integratsiyasi

**Muhim:** Foydalanuvchi yuqoridagilarni so'rasa — hurmat bilan eslating. MVP'dan chetga chiqmang.

---

## TEXNIK STEK

### Ishlatamiz

| Tur | Tanlov | Versiya |
|---|---|---|
| Frontend | Flutter | 3.x (latest stable) |
| Til | Dart | 3.x |
| State management | **Riverpod** | 2.x |
| Routing | **go_router** | 14.x |
| Backend | Firebase | latest |
| - Auth | firebase_auth | latest |
| - Database | cloud_firestore | latest |
| - Push | firebase_messaging | latest |
| - Storage | firebase_storage | latest |
| - Functions | cloud_functions | latest |
| Maps | google_maps_flutter | latest |
| Location | geolocator | latest |
| Permissions | permission_handler | latest |
| Localization | easy_localization | latest |
| Code gen | freezed, json_serializable | latest |
| Linting | very_good_analysis | latest |

### Nega Riverpod (Provider/Bloc o'rniga)?
- Compile-time safe
- Zamonaviy va testlash oson
- Yangi boshlovchi uchun ham mantiqiy

### Nega go_router?
- Flutter rasmiy tavsiyasi
- Auth state'ni hisobga oladi
- Deep linking

---

## LOYIHA STRUKTURASI

Clean Architecture'ga moslashtirilgan, lekin **yangi boshlovchi uchun soddalashtirilgan**:

```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── firebase_constants.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_dimensions.dart
│   ├── routing/
│   │   ├── app_router.dart
│   │   └── app_routes.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── location_service.dart
│   │   └── notification_service.dart
│   └── utils/
│       ├── validators.dart
│       ├── formatters.dart
│       └── extensions.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/user_model.dart
│   │   │   └── repositories/auth_repository.dart
│   │   └── presentation/
│   │       ├── providers/auth_provider.dart
│   │       ├── screens/
│   │       │   ├── welcome_screen.dart
│   │       │   ├── sign_up_screen.dart
│   │       │   └── sign_in_screen.dart
│   │       └── widgets/
│   ├── child_management/
│   ├── dashboard/
│   ├── activity/
│   ├── location/
│   ├── schedules/
│   ├── sos/
│   └── settings/
│
└── shared/
    ├── widgets/
    │   ├── primary_button.dart
    │   ├── secondary_button.dart
    │   ├── custom_text_field.dart
    │   └── child_avatar.dart
    └── models/
        └── result.dart

assets/
├── images/
├── icons/
└── translations/
    ├── uz.json
    ├── ru.json
    └── en.json
```

---

## DIZAYN TIZIMI

UI dizayn `Parent_app_MVP.pdf` faylida. Asosiy parametrlar:

### Ranglar (lib/core/theme/app_colors.dart)

```dart
class AppColors {
  // Backgrounds
  static const background = Color(0xFF0A0A12);
  static const surface = Color(0xFF1C1C24);
  static const surfaceVariant = Color(0xFF252530);

  // Primary accent (lime green from UI)
  static const primary = Color(0xFFC5F562);
  static const primaryDark = Color(0xFFA3CE4F);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9999A8);
  static const textTertiary = Color(0xFF6B6B78);

  // Status
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF60A5FA);

  // Borders
  static const border = Color(0xFF2A2A35);
  static const divider = Color(0xFF1F1F28);
}
```

### Tipografika
- Sarlavha XL: 28sp, weight 700
- Sarlavha L: 22sp, weight 600
- Body: 16sp, weight 400
- Body S: 14sp, weight 400
- Label: 12sp, weight 500

Shrift: **Inter** (Google Fonts)

### Spacing
- xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48

### Radius
- Small: 8, Medium: 16, Large: 24, Pill: 999

### Tugma stillari
- **Primary:** Pill (radius 999), lime green fon, qora matn, 56dp height
- **Secondary:** Pill, transparent fon, oq border, oq matn

### Theme: **DARK MODE** (default)

---

## QURISH TARTIBI (8 ta bosqich)

### 🏗 Bosqich 0: Loyiha sozlash (1-hafta)

1. Flutter loyiha tuzilmasini tayyorlash
2. Dependency'larni qo'shish (pubspec.yaml)
3. Folder strukturasini yaratish
4. Theme tizimini quyish (colors, text styles, dimensions)
5. go_router asosiy konfiguratsiyasini yaratish
6. Firebase loyihasini yaratish (foydalanuvchi qiladi)
7. Firebase'ni ulash (FlutterFire CLI orqali)

**Deliverable:** Bo'sh ekran ochiladi, Firebase ulangan, theme ishlaydi.

### 🔐 Bosqich 1: Autentifikatsiya (2-hafta)

1. Welcome screen UI
2. Sign up screen (telefon raqami)
3. Sign in screen
4. Forgot password screen
5. Phone verification (OTP)
6. Auth provider (Riverpod)
7. Firebase Auth integratsiyasi
8. Auth state'ga qarab routing (sign in qilingan → dashboard, qilinmagan → welcome)

**Deliverable:** Foydalanuvchi ro'yxatdan o'ta oladi, kira oladi, chiqib keta oladi.

### 👶 Bosqich 2: Bola boshqaruvi (3-hafta)

1. "Yangi bola qo'shish" empty state
2. Bola ma'lumotlarini kiritish (ism, yosh, hudud, foto)
3. Oila kodi generatsiyasi (5 raqamli unique kod)
4. "Bola ulayajak" kutish ekrani
5. Firestore'ga bola ma'lumotlarini saqlash
6. Bir nechta bola boshqaruvi

**Deliverable:** Ota-ona Firebase'da bola profilini yarata oladi, oila kodini ko'ra oladi.

### 🏠 Bosqich 3: Dashboard (4-hafta)

1. Asosiy dashboard UI (hozircha mock data bilan)
2. Bolalar ro'yxati (yuqoridagi avatarlar)
3. "Bugun sarflangan vaqt" karta (mock)
4. Quick actions grid
5. Bottom action bar
6. Notification bell (notification ekraniga link)

**Deliverable:** Chiroyli dashboard ko'rinadi, lekin haqiqiy ma'lumot kelmaydi (Child App'siz).

### 📍 Bosqich 4: Joylashuv (5-6 hafta)

1. Google Maps integratsiyasi
2. Real-time joylashuv ko'rsatish
3. Harakatlanish tarixi (chiziq)
4. Geo-zonalar yaratish (uy, maktab)
5. Geo-zona bildirishnomalari
6. Cloud Functions (zona kirish/chiqish)

**Deliverable:** Bola Child App'dan joylashuv yuborganda Parent App xaritada ko'rsatadi.

### 📊 Bosqich 5: Statistika va jadvallar (7-8 hafta)

1. Faollik ekrani (haftalik grafik) — fl_chart paketi
2. Ilovalar bo'yicha vaqt (mock data)
3. Jadvallar UI (uyqu vaqti, dars vaqti)
4. Jadvalni saqlash (Firestore)
5. Ilova cheklovlari UI (mock)

**Deliverable:** Statistika va jadvallar UI tayyor, mock data bilan ishlaydi.

### 🆘 Bosqich 6: SOS va xabarlar (9-hafta)

1. SOS qabul qilish (Cloud Function → FCM)
2. Push xabarlar (notification handling)
3. Notification center ekrani
4. SOS xaritada ko'rsatish (qayerda bosildi)

**Deliverable:** Bola SOS bossa, ota-ona darhol push xabar oladi.

### ⚙️ Bosqich 7: Sozlamalar va polish (10-11 hafta)

1. Sozlamalar ekrani
2. Profil tahrirlash
3. Til o'zgartirish (uz, ru, en)
4. Parolni o'zgartirish
5. Chiqish
6. Xato handling barcha joyda
7. Loading state'lar
8. Empty state'lar

**Deliverable:** To'liq Parent App MVP tayyor.

### 📱 Bosqich 8: Child App minimal (12-16 hafta)

Yangi loyiha sifatida quriladi (`farzandim_child`):

1. Welcome screen
2. Oila kodi kiritish
3. Ruxsatlar berish (joylashuv, bildirishnoma)
4. Asosiy ekran (SOS tugma)
5. Background location service
6. SOS yuborish (FCM Cloud Function orqali)

**Deliverable:** Child App ham ishlaydi, Parent App bilan bog'lanadi.

---

## FIREBASE STRUKTURASI (Firestore)

```
families/                              (collection)
  ├── {familyId}/                      (document)
  │   ├── name: "Aliyev oilasi"
  │   ├── createdAt: timestamp
  │   ├── parentIds: [uid1, uid2]
  │   └── code: "24370"
  │
users/                                 (collection)
  ├── {userId}/                        (document)
  │   ├── email: "..."
  │   ├── phone: "+998..."
  │   ├── role: "parent" | "child"
  │   ├── familyId: "..."
  │   ├── name: "..."
  │   ├── photoUrl: "..."
  │   └── createdAt: timestamp
  │
children/                              (collection)
  ├── {childId}/                       (document)
  │   ├── userId: "..."
  │   ├── familyId: "..."
  │   ├── name: "..."
  │   ├── age: 12
  │   ├── region: "Toshkent"
  │   ├── photoUrl: "..."
  │   ├── deviceModel: "Redmi Note 12"
  │   ├── lastLocation: {lat, lng, timestamp}
  │   ├── isOnline: true
  │   └── batteryLevel: 75
  │
locations/                             (collection)
  ├── {locationId}/                    (document)
  │   ├── childId: "..."
  │   ├── lat: 41.123
  │   ├── lng: 69.456
  │   ├── accuracy: 10
  │   └── timestamp: timestamp
  │
geoZones/                              (collection)
  ├── {zoneId}/                        (document)
  │   ├── familyId: "..."
  │   ├── name: "Uy" | "Maktab"
  │   ├── lat: 41.123
  │   ├── lng: 69.456
  │   ├── radius: 100  (meters)
  │   └── alerts: { onEnter: true, onExit: true }
  │
schedules/                             (collection)
  ├── {scheduleId}/                    (document)
  │   ├── childId: "..."
  │   ├── type: "sleep" | "school" | "hobby"
  │   ├── days: [1, 2, 3, 4, 5]  (Mon-Fri)
  │   ├── startTime: "22:00"
  │   └── endTime: "07:00"
  │
notifications/                         (collection)
  ├── {notificationId}/                (document)
  │   ├── userId: "..."
  │   ├── type: "sos" | "zoneEnter" | "zoneExit" | ...
  │   ├── title: "..."
  │   ├── body: "..."
  │   ├── data: {...}
  │   ├── read: false
  │   └── timestamp: timestamp
```

---

## CODING STANDARTLARI

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `lowerCamelCase` (Dart convention) yoki `SCREAMING_SNAKE` ba'zi joylarda
- Private: `_underscore` prefix

### Fayl strukturasi
1. Imports (Flutter, paketlar, ichki)
2. Constants (agar bo'lsa)
3. Class
4. Helper functions (agar bo'lsa)

### Riverpod patterns
- `StateNotifier` for complex state
- `Provider` for read-only data
- `FutureProvider` for async data
- `StreamProvider` for streams (Firestore)

### Error handling
Har bir async funksiya `try/catch` bilan o'ralgan bo'lishi kerak. Result pattern ishlatamiz:

```dart
class Result<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;
}
```

### Comments
- Murakkab kod uchun o'zbekcha izoh yozing
- Public API uchun `///` (DartDoc)
- Inline `//` — qisqa tushuntirishlar uchun

---

## BIRINCHI QADAM — HOZIRDAN BOSHLAYMIZ

Foydalanuvchi `farzandim` papkasida tayyor Flutter loyihasi yaratgan (eski boilerplate counter app bilan).

### Sizning birinchi vazifangiz:

1. **Foydalanuvchi bilan salomlashing**
2. **Loyihaning hozirgi holatini tekshiring**:
   ```
   ls -la lib/
   cat pubspec.yaml
   ```
3. **Birinchi qadamni tushuntiring:**
   "Avval biz pubspec.yaml'ga kerakli paketlarni qo'shamiz, keyin folder strukturasini yaratamiz, keyin theme tizimini quyamiz. Bu 30-40 daqiqa oladi. Tayyor bo'lsa, boshlaymiz?"
4. **Foydalanuvchi tasdiqlasa**, **Bosqich 0**'ni boshlang.
5. **Har qadamdan keyin** foydalanuvchidan tasdiq oling: "Endi `flutter run` qiling, ishlayaptimi?"

### Muhim eslatmalar

- **Firebase loyihasini foydalanuvchi qo'lda yaratadi** (console.firebase.google.com'da). Siz ko'rsatma berasiz, lekin uning o'rniga qila olmaysiz.
- **API kalitlari, Google Maps key** — foydalanuvchi qo'shadi, siz `.env` yoki `firebase_options.dart`'ga qaerga qo'yishni aytasiz.
- **Sekret ma'lumotlar** (API keys, passwords) hech qachon Git'ga commit qilinmasligi kerak. `.gitignore` faylini to'g'ri sozlang.

---

## UI ASOSI: PDF FAYLLARI

3 ta PDF fayl loyiha papkasida saqlash kerak:
- `docs/Parent_app_MVP.pdf` — 49 sahifa
- `docs/Child_app_UI_MVP.pdf` — 30 sahifa
- `docs/Admin_panel_WEB_UI_MVP.pdf` — 23 sahifa

Foydalanuvchi har bir ekran uchun PDF'dan tegishli sahifani sizga ko'rsatadi (yoki qo'lda tasvirlab beradi).

**Sizning vazifangiz:** UI'ni AYNI shu PDF'dagidek qiling. Erkin yo'l qo'ymang. Pixel-perfect bo'lmasligi mumkin, lekin **dizayn umumiy ko'rinishi bir xil bo'lishi shart**.

---

## TEKSHIRISH RO'YXATI (HAR BOSQICH OXIRIDA)

✅ Kod kompilyatsiya bo'lyaptimi? (`flutter analyze`)  
✅ Lint xato yo'qmi?  
✅ Dastur ishga tushyaptimi? (`flutter run`)  
✅ Yaratilgan ekran PDF'dagi dizaynga mos keladimi?  
✅ Foydalanuvchi har bir o'zgarishni tushunyaptimi?  
✅ Git commit yozilganmi? (har bosqich oxirida)

---

## YAKUN

Bu hujjatni o'qib bo'lgach, foydalanuvchidan kontekstni tasdiqlashni so'rang:

> "Salom! Men Farzandim loyihasini siz bilan birga qurish uchun tayyorman.
>
> CLAUDE.md ni o'qidim — quyidagi narsalarni tushundim:
>
> - Loyiha: Parent + Child + Admin Panel ekotizimi
> - Hozir: Slice MVP qurmoqdamiz (4 oy)
> - Texnologiya: Flutter + Firebase + Riverpod
> - Birinchi qadam: Bosqich 0 — Loyiha sozlash
>
> To'g'ri tushunganmi? Boshlaymizmi?"

Foydalanuvchi tasdiqlasa, **Bosqich 0**'ni boshlang. Sabr-toqat bilan, tushuntirib, qadamma-qadam.

**Omad! 🚀**
