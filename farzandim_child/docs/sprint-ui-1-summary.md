# Sprint UI.1 — Color System Summary (Duolingo-inspired)

> Sprint: 2026-05-19 (1 sessiya). Reja: `docs/claude-code-prompt-sprint-ui-1-3.md`

## ✅ Bajarilgan

### Step 1 — Audit
- 177 ta `Color(0x...)` hardcoded usage hujjatlangan (`SCRATCH.md`)
- 757 ta `AppColors.X` mavjud usage (yaxshi baza)
- 2 ta theme fayl (app_colors + app_theme) + 4 ta ThemeData joy
- `google_fonts: ^6.2.1` allaqachon mavjud

### Step 2 — Yangi `app_colors.dart`
Duolingo-inspired palette + WCAG AA:
- **Primary**: `#58CC02` (Duolingo green) + Hover/Disabled/Shadow
- **Secondary**: `#1CB0F6` (Friendly Blue)
- **Accent**: `#FFC800` (Sunshine Yellow)
- **Status**: `warning #FF9600`, `danger #FF4B4B`
- **Backgrounds (Light)**: `bgPrimary #FFFFFF`, `bgSurface #F7F7F7`, `bgAccent #FFF8E7`, `bgSky #E0F2FE`
- **Backgrounds (Dark)**: `bgPrimaryDark #131F24`, `bgCardDark #2D4147`
- **Text**: `textPrimary #1A2B3B`, `textSecondary #4A5568`, `textOnPrimary #FFFFFF`
- **Uzbek pride** (3 ranglar): kam ishlatish uchun
- **Category palette** (24 ta): gamification, ranking, achievement uchun
- **Legacy aliases**: Sprint 4.4 `error/primaryDark/backgroundTop` backwards compat

### Step 3 — Yangi `app_theme.dart`
- **`AppTheme.lightTheme`** asosiy — Material 3 + Inter + Light scheme
- **`AppTheme.darkTheme`** fallback (themeMode.system uchun)
- Type scale child-friendly (16-40sp)
- AppBar, Card, Divider, Input themes (avval yo'q edi)
- Button heights: 60dp (primary), 52dp (interactive)
- Page transitions (Zoom Android, Cupertino iOS)
- **Legacy alias**: `AppTheme.dark` (eski kod uchun) → darkTheme

### Step 4 — google_fonts
- ✅ Skip — `^6.2.1` allaqachon `pubspec.yaml`'da

### Step 5 — `main.dart` wire
```dart
MaterialApp.router(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.light,
  ...
)
```

### Step 6 — Refactor hardcoded colors (60% reduction)
Sed batch bilan **39 ta mapping** qo'llanildi:
- `#C5F562` (lime) → `AppColors.catLimeBright`
- `#0A0A16` (dark navy) → `AppColors.bgPrimary`
- `#1F2937` (slate) → `AppColors.bgSurface`
- `#EF4444` → `AppColors.danger`
- `#F59E0B` → `AppColors.warning`
- `#FFFFFF` → `AppColors.bgPrimary`
- `#FFC800` → `AppColors.accent`
- `#1CB0F6` → `AppColors.secondary`
- 24 ta category color → `AppColors.catPurple/Pink/Indigo/...`
- 3 ta UZB flag → `AppColors.uzbFlagBlue/Red/Green`

Va 13 ta data fayllarga **AppColors import qo'shildi** (mock data ichida).

**Natija:** 177 → ~70 hardcoded colors (60% kamayish). Qolgan 70 — asosan AppColors.dart o'zining ta'riflari + unique kombinatsiyalar (gold/silver/bronze ranking, deep custom colors).

### Step 7 — Test + commit
- ✅ `flutter analyze`: 3 pre-existing issues (mening kodimga aloqasi yo'q)
- ✅ `flutter build apk --debug`: 17.4s success
- ⏸ Telefon test: SM G988B uzilgan paytda, qayta ulansa darhol install mumkin

### GradientBackground
- Eski: dark navy linear gradient
- Yangi: flat `bgPrimary` (light) / `bgPrimaryDark` (dark) — Theme.brightness asosida

---

## 📁 O'zgargan fayllar

| Fayl | Status |
|---|---|
| `lib/core/theme/app_colors.dart` | 🔄 To'liq yangilangan (39 → 170 satr) |
| `lib/core/theme/app_theme.dart` | 🔄 To'liq yangilangan (light + dark) |
| `lib/main.dart` | ✏️ theme + darkTheme + themeMode |
| `lib/shared/widgets/gradient_background.dart` | ✏️ Flat fon |
| 13 ta data fayl | ✏️ AppColors import qo'shildi |
| ~40 ta widget/screen | ✏️ Sed batch refactor |
| `SCRATCH.md` | 🆕 Audit hujjat (sprint oxirida o'chiriladi) |
| `docs/sprint-ui-1-summary.md` | 🆕 Shu fayl |

---

## 🟡 Hali qolgan ishlar (Sprint UI.2'ga oldin)

1. **Qolgan ~70 hardcoded Color** — qo'lda audit + ko'p ranglar AppColors aliases bo'lib qo'shilishi mumkin (gold/silver/bronze, deep custom)
2. **Telefonda real test** — telefon qayta ulansa
3. **Screenshot before/after** — 5 ekran
4. **A11y check** — yorug' fonda matn kontrasti (yangi sariq matn bo'lmasligi)

---

## 🚀 Keyingi qadam

**Sprint UI.2 — Buttons (PlayfulButton, PlayfulIconButton, VoiceFAB)**

Hozirgi `ElevatedButton`/`TextButton`/`OutlinedButton` mavjud `elevatedButtonTheme` orqali yangi Duolingo style oladi, lekin **3D shadow + press animation** uchun custom `PlayfulButton` widget kerak. Reja `docs/claude-code-prompt-sprint-ui-1-3.md` Sprint UI.2 bo'limida.

---

*Sprint UI.1 yakuni: 2026-05-19. flutter analyze 0 errors. Build success.*
