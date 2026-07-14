# Farzandim (ota-ona ilovasi) — AI Agent uchun HANDOFF

> Bu hujjatni **birinchi** o'qi. Sen Farzandim **ota-ona** Flutter ilovasi ustida
> ishlaysan: yangi sahifalar yasaysan yoki mavjudlarini to'g'rilaysan. Loyiha
> hozir **"Parvoz"** (dark ko'k) dizayn tizimiga ekran-ba-ekran ko'chirilmoqda.
> `Farzandim/CLAUDE.md` — umumiy loyiha qo'llanmasi (asosiy vizyon), bu hujjat
> esa **amaldagi konvensiyalar**.

---

## 1. Ish oqimi (har safar)

Dizayner **rasm** yoki **Figma Make** eksporti (React/TSX papka) beradi. Sen:
1. **Skaut**: mavjud kod (ekran, provider, repo, route) va dizayn manbasini top.
2. **Spetsifikatsiya**: dizayndan aniq **rang / gradient / o'lcham / font / matn**ni chiqar.
3. **Yoz**: MAVJUD faylni **JOYIDA update** qil (yangi ekran bo'lsa yarat), **REAL backend** logikasini ula (mock emas).
4. **Tekshir**: `flutter analyze <fayl>` (0 xato shart) + `dart format <fayl>`.
5. **Adversarial review**: real render/logic buglarni izla (7-bo'lim).
6. **Tuzat → commit → push** (2-bo'lim qoidalari bilan).

Katta ishda avval **rejani** ayt, kerak bo'lsa 1-2 aniq savol ber, keyin ishla.

---

## 2. QAT'IY QOIDALAR (buzma!)

- **`flutter analyze --fatal-infos` = 0** — CI gate (`parent-quality` deploy'ni bloklaydi). Har `info` ham xato. `dart format` ham qil.
- **Faqat O'ZING tegan fayllarni commit qil.** Ishchi daraxtda **~55+ oldindan o'zgargan** fayl bor (`child_model.dart`, `backend/*`, `voice_message/*`, ...) — **ularga TEGMA**. `git add <aniq fayllar>` bilan faqat o'zingnikini stage qil; hech qachon `git add -A`/`.` qilma.
- **`backend/*` fayllarini commit QILMA** — push productionga (farzandimedu.uz) deploy bo'ladi. Faqat foydalanuvchi **aniq ruxsat** bersa.
- **Git**: push'dan oldin `git pull --rebase --autostash origin main`. `main`ga push. Commit oxirida:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Hook/CI bypass qilma.
- **i18n**: `easy_localization`, `'key.tr()'`. Har yangi kalitni **uz + ru + en** — UCHALASIGA qo'sh. `namedArgs: {'count': '$x'}`, JSON'da `{count}`.
- **Dizayn manba papkalarini** ("Consistent Page Design1", "Professional Page Design4", ...) **commit QILMA** — faqat kerakli assetlarni `assets/images/...`'ga nusxala + `pubspec.yaml`'ga papkani qo'sh (Flutter kichik papkalarni avtomatik olmaydi).

---

## 3. Parvoz dizayn tizimi

**Lokal ranglar** (har faylda `const` sifatida qayta e'lon qilinadi — shared emas):
```dart
const _bg = Color(0xFF00060A);         // ekran foni (dark)
const _blue = Color(0xFF216BFF);       // brend ko'k (CTA, DON teg, faol)
const _card = Color(0xFF1A1F23);       // karta/qator foni (ba'zan 0xFF12171E)
const _cardBorder = Color(0x1FFFFFFF); // oq ~12% (hairline rim)
const _dim = Color(0x99FFFFFF);        // oq 60% (ikkilamchi matn)
const _green = Color(0xFF34C759);      // toggle ON / online
```

**Fontlar** (har faylda o'z helperini e'lon qil):
```dart
TextStyle _unb(double s, {FontWeight w = FontWeight.w600, Color c = Colors.white,
  double ls = -0.5}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w,
  color: c, letterSpacing: ls, height: 1.3);            // SARLAVHA (Unbounded)
TextStyle _pop(double s, {FontWeight w = FontWeight.w400, Color c = Colors.white})
  => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.5); // body (Poppins)
```
Unbounded'da **manfiy letterSpacing** dizayn qismi. `w: FontWeight.w600` default —
uni takror yozma (`avoid_redundant_argument_values`).

**Umumiy komponentlar** (`lib/shared/widgets/parvoz_ui.dart`): `ParvozGlass`,
`ParvozPrimaryButton`, `ParvozSecondaryButton`, `ParvozTextField`, `ParvozBackButton`,
`ParvozBrandLogo` (logo: `assets/icons/parvoz_logo_mark.svg`).

**Ikonlar**: `solar_icons` (`SolarIconsBold` / `SolarIconsOutline`).
- ⚠️ `SolarIconsOutline.plus` **buzuq** (kvadrat-plus) — toza `+` uchun **`Icons.add_rounded`**.
- 4-doira "apps" ikoni: `SolarIconsBold.widget_6` (oddiy `widget` = kvadratlar).

### Tugmalar (buttons)

**1. Primary (ko'k, asosiy amal)** — "Saqlash", "Keyingisi", "Ulanish":
```dart
GestureDetector(
  onTap: enabled ? onTap : null,
  behavior: HitTestBehavior.opaque,
  child: Opacity(
    opacity: enabled ? 1 : 0.5,                 // o'chiq holat = xira
    child: ParvozGlass(
      blue: true,                               // ko'k to'ldirilgan pill
      child: loading
        ? const SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
        : Text(label, style: _pop(16, w: FontWeight.w500)),
    ),
  ),
)
```
Yoki tayyor `ParvozPrimaryButton(label:, onPressed:, showArrow:, loading:, enabled:)`.
`ParvozGlass` default balandligi **60**, radius **999** (pill). "O'chiq" tugma =
`Opacity(0.45–0.5)` + `onTap: null`.

**2. Secondary (shisha, ikkilamchi)** — "Rasm yuklash", "Manzil qo'shish", "Limit qo'yish", "Batafsil":
- Oddiy: `ParvozSecondaryButton(label:, onPressed:, leading:)` yoki `ParvozGlass(blue: false, ...)`.
- **"Secondry shisha"** ko'rinishi (qo'lda — `add_child_screen.dart` `_GlassChip` /
  `connect_child_sheet.dart` kod qutisi namunasi):
  ```dart
  ClipRRect(borderRadius: BorderRadius.circular(999), child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: [Colors.white.withValues(alpha: 0.11),
                 Colors.white.withValues(alpha: 0.025)]),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2)),
      child: ...)))
  ```
- Yengil variant (blursiz): `Container(color: Colors.white.withValues(alpha: 0.1), radius: 999)`.

**3. Kvadrat ikon-tugma** (orqa / yordam, header) —
`Container(56x56, color: _card, radius: 16, border: _cardBorder, child: Icon(24, white))`.

**Premium sahifasidagi maxsus tugmalar** (`parvoz_premium_screen.dart`):
- CTA **"$5/oy"**: `Stack[ Positioned.fill(ColoredBox #216BFF), diagonal oq sheen
  (LinearGradient transparent→white50→transparent, ~117°), Row(matn) ]`.
  ⚠️ `ColoredBox`ni **`Positioned.fill`**ga o'ra — aks holda Stack'da 0 o'lchamga tushib ko'rinmaydi.
- **"PREMIUM" pill**: `Container(gradient 108.7° #21AEFF→#3F3FCC→#5D1499, radius 24, border oq 10%)`.
- **"Batafsil"**: shaffof shisha pill `Container(color: white 10%, radius: 999)`.

### Kartalar (cards)

**1. Qator / sozlama kartasi** (settings, app qatorlari):
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: _card,                                 // 0xFF1A1F23 yoki 0xFF12171E
    borderRadius: BorderRadius.circular(24),      // ovalroq = kattaroq radius
    border: Border.all(color: _cardBorder),       // oq ~12% hairline
  ),
  child: Row(...),                                // ikon(28) + matn + chevron
)
```
Qatorlar orasi **4px** (Figma sozlamalar) yoki **10px** (varaqlar). Bosiladigan bo'lsa
`GestureDetector(behavior: HitTestBehavior.opaque)`ga o'ra.

**2. Shisha karta** (Premium "Afzalliklar" kabi):
- ⚠️ Ko'p Figma "shisha" kartalari aslida **tekis** `Container(color: white 10%, radius: 32)`
  — **`BackdropFilter` YO'Q**. Haqiqiy blur qo'shsang eksportdan **farq qiladi** (frostroq).
  Faqat dizaynda ataylab kerak bo'lsagina `BackdropFilter` ishlat.

**3. Layered banner karta** (Premium banner — `settings_screen.dart`):
`Container(clipBehavior: antiAlias, color: _card, radius: 24, border)` ichida
`Stack[ xira aurora blob (ImageFiltered(blur) + LinearGradient #0055FF→#3CF9FF→#6A00FF),
ko'k radial tint (RadialGradient #508AFF 40%), mazmun (Padding) ]`.

**4. Ikon-chip** (karta ichidagi ikon doirasi):
`Container(44x44, color: _chipBg 0xFF1B2128, shape: circle, child: Icon(22, white))`.

**Umumiy qoida**: karta = `_card` fon + `_cardBorder` (oq 8–12%) hairline rim +
radius **20–28** (ovalroq = kattaroq), har doim dark `_bg` ustida. `ParvozGlass` o'zi
yumshoq soya beradi.

**Tortiladigan varaq (bottom sheet)** — namunalar: `daily_limit_sheet.dart`,
`block_apps_screen.dart`, `connect_child_sheet.dart`:
`showModalBottomSheet(isScrollControlled: true, backgroundColor: transparent,
barrierColor: black 55%)` → `DraggableScrollableSheet` (initial 0.9, min 0.45, max 0.96,
snap [0.9]) + `_opened`/`_dismissing` flag + `NotificationListener` (extent<=0.46 da pop).
Har `ListView`'da `controller: scrollController` + `AlwaysScrollableScrollPhysics()`.

---

## 4. Backend / real data (MOCK EMAS)

- Dio → **farzandimedu.uz** (production). State — **Riverpod**. Routing — **go_router**.
- **App limits** (`app_restrictions`): `appRestrictionRepositoryProvider` facade —
  `setLimit(childId, packageName, appName, limitMinutes)` / `removeLimit(...)`. Limit
  **DAQIQADA**; wire'da `dailyLimitMs = daqiqa*60000`. **0 daqiqa = BLOK**, "limit yo'q" =
  record yo'q → o'chirish uchun `removeLimit` (setLimit(0) EMAS). Ro'yxat:
  `installedAppsProvider(childId)`, joriy limitlar `restrictionsProvider(childId)`.
  Yozgach `ref.invalidate(restrictionsProvider(childId))`.
- **Leaderboard** (`gamification`): `leaderboardProvider` (StateNotifier, **paginated**
  15/sahifa, `loadMore()`), `state.currentChild` = "sizning bolangiz" (absolyut rank),
  avatar = `leaderboardRepositoryProvider.avatarUrl(childId)` (network + harf fallback).
  Ball = `entry.xp` (UI'da "DON" deb yozamiz — **yorliq**, qiymat = xp).
- **Bola ulanishi**: `child.isConnected` (bool). `childByIdProvider(childId)` kuzat;
  tez poll: `ref.read(childrenRefreshTickProvider.notifier).state++` (invalidate emas).
- **Ilova nomlari/ikonlari**: `lib/core/utils/app_brand.dart` → `friendlyAppName(pkg, [raw])`
  (org.telegram.messenger→Telegram), `appAvatarColor`, `appInitial`. `AppIconWidget` ikon
  yo'q bo'lsa brend rangli harf-avatar.
- **Bola ulanmasa** ilova ro'yxati bo'sh keladi — **kutilgan** (xushmuomala empty state).
- Backend DTO'lar: **ValidationPipe whitelist** — har maydonda class-validator dekoratori shart.
- Media/avatar: signed MinIO URL telefondan yetmaydi — `@Public` proxy stream ishlatiladi.

---

## 5. Yangi route qo'shish (3 joy)

1. `lib/core/routing/app_routes.dart`: `static const String x = '/x';`
2. `lib/core/routing/app_router.dart`: yuqorida ekran importi (alifbo tartibida) +
   `GoRoute(path: AppRoutes.x, pageBuilder: (c,s) => _slidePage(const XScreen()))`.
3. Navigatsiya: `context.push(AppRoutes.x)`.

---

## 6. Figma Make eksporti bilan ishlash

- `src/app/App.tsx` — **toza mantiq** (interaksiya, holat, scroll). Undan boshla.
- `src/imports/<Page>/index.tsx` — **xom SVG** (ko'p qismi `opacity-0` dead-code).
  Faqat **gradient stoplari, ranglar, o'lchamlar, blur (feGaussianBlur=sigma)** kerak.
- `.png`'lar odatda **memoji avatar / medal / rasm** — kerakli bo'lsa `assets/`'ga nusxala.
- Murakkab god-ray/gradient fonni Flutter'da **native qayta qur** (LinearGradient +
  RadialGradient + `ImageFiltered(ImageFilter.blur)` + `Transform.rotate`).
- CSS `linear-gradient(Ndeg)` yo'nalishi = `(sin N, -cos N)` → Flutter `Alignment`.

---

## 7. Tez-tez uchraydigan REAL buglar (review'da izla)

- **`const ColoredBox(color: x)` `Stack` ichida** → 0 o'lchamga tushadi (ko'rinmaydi).
  `Positioned.fill(child: ColoredBox(...))` yoki `SizedBox.expand` child ber.
- **`Row`ning `Expanded`siz bolasida `width: double.infinity`** → "forces an infinite width".
  `Expanded`/`Flexible`ga o'ra.
- **i18n kalit yetishmasligi** — `.tr()` kaliti 3 tilda ham bormi tekshir.
- **`await`dan keyin `context`/`ref`** — `if (!mounted) return;` guard. `mutable` field
  (`_period`) `await`lar orasida o'zgarsa — kalitni bir marta capture qil.
- **Asset** — `pubspec.yaml`'ga kichik papkani qo'sh; katta PNG'ga `cacheWidth` ber.

---

## 8. Bajarilgan Parvoz redizaynlar (namuna sifatida qara)

`add_child_screen`, `controls_setup_screen` (Nazorat), `daily_limit_sheet` (Kunlik vaqt
limiti), `block_apps_screen`, `rejimlar_sheet`, `addresses_setup_screen`,
`connect_child_sheet` (Bolani ilovasini ulash), `settings_screen` (Tizim so'zlamalari) +
`parvoz_premium_screen`, `leaderboard_screen` (DON reytingi), `add_edit_geo_zone_screen`.

**Ochiq ishlar / cheklovlar**:
- Premium "Premiumga ulanish" — hozircha "tez kunda" toast (in-app purchase yo'q).
- Farzand tahrirlash/o'chirish → **Profil (Akkount)** sahifasida.
- Leaderboard: region filtri olib tashlangan; motorcycle fon yo'q; medallar ~2.8MB.
- Premium god-ray fon — SVG'ning native yaqinlashuvi.

---

## 9. Tez topish

- Namunaviy Parvoz ekranlar: `dashboard_screen.dart`, `daily_limit_sheet.dart`,
  `connect_child_sheet.dart`, `leaderboard_screen.dart`, `settings_screen.dart`.
- UI kit: `lib/shared/widgets/parvoz_ui.dart`.
- Routing: `lib/core/routing/app_routes.dart`, `app_router.dart`.
- i18n: `assets/translations/{uz,ru,en}.json`.
- Util: `lib/core/utils/app_brand.dart` (ilova nomi/avatar).

Omad! Kichik, tekshirilgan qadamlar bilan ishla — har o'zgarishdan keyin
`flutter analyze` **0** bo'lsagina commit.
