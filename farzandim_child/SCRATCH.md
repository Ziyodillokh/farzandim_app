# Sprint UI.1 — Theme Audit (DELETE after sprint done)

> Audit before refactoring. Per spec: "Document in SCRATCH.md".
> Sprint reja: `docs/claude-code-prompt-sprint-ui-1-3.md`

---

## 1. Current theme files

| File | Role | Notes |
|---|---|---|
| `lib/core/theme/app_colors.dart` | `AppColors` class | **Dark theme palette**, lime green primary |
| `lib/core/theme/app_theme.dart` | `AppTheme.dark` getter | Material 3 + Inter (google_fonts) + dark only |
| `lib/main.dart` | `MaterialApp(theme: AppTheme.dark)` | No `themeMode` override — single theme |

## 2. Current palette (Dark · Lime green)

```dart
primary           = #C5F562  (lime green)
primaryDark       = #A8D946

backgroundTop     = #1B212F  (dark slate gradient)
backgroundBottom  = #0A0A16  (deep navy gradient)

surface           = #1F2937  (slate-800)
surfaceVariant    = #2D3748  (slate-700)

textPrimary       = #FFFFFF  (white)
textSecondary     = #A0AEC0  (slate-300)
textTertiary      = #718096  (slate-500)

success           = #48BB78  (green)
error             = #EF4444  (red)
warning           = #F59E0B  (amber)

border            = #374151  (slate-600)
```

**Tone:** Dark navy gradient, lime accent (Parent App bilan brand consistency).

## 3. Current AppTheme features (saqlanadi)

- ✅ `useMaterial3: true`
- ✅ `google_fonts: ^6.2.1` Inter shrift (Step 4 skip — allaqachon bor)
- ✅ Material 3 type scale (displayLarge → labelSmall) child-friendly sizes (16-40sp)
- ✅ Button heights: `_minButtonHeight = 60`, `_minInteractiveHeight = 52`
- ✅ Page transitions (ZoomPageTransitions Android, CupertinoPageTransitions iOS)
- ⚠️ `scaffoldBackgroundColor: Colors.transparent` — har screen `GradientBackground` wrap'i bilan
- ⚠️ Yo'q: `appBarTheme`, `cardTheme`, `dividerColor`

## 4. Counts (grep)

| Item | Count |
|---|---|
| `Color(0x...)` hardcoded (lib/) | **177** |
| `AppColors.X` usages (lib/) | **757** |
| Files with hardcoded `Color()` | top 15 listed below |

## 5. Top hardcoded-color files

```
lib/core/theme/app_colors.dart                                  ← own definitions
lib/features/ranking/data/mock_ranking.dart
lib/features/ranking/data/repositories/ranking_backend_repository.dart
lib/features/ranking/presentation/widgets/top_three_podium.dart
lib/features/ranking/presentation/widgets/ranking_user_tile.dart
lib/features/gamification/data/models/achievement.dart
lib/features/gamification/data/models/gamification_status.dart
lib/features/gamification/presentation/screens/profile_screen.dart
lib/features/gamification/presentation/widgets/don_wallet_card.dart
lib/features/gamification/presentation/widgets/streak_indicator.dart
lib/features/audiobooks/data/mock_audiobooks.dart
lib/features/audiobooks/data/repositories/audiobooks_backend_repository.dart
lib/features/books/data/repositories/books_backend_repository.dart
lib/features/dashboard/presentation/screens/child_dashboard_screen.dart
lib/features/dashboard/presentation/widgets/photo_request_banner.dart
... (162 more)
```

**Note:** Ko'p `Color(0xFF...)` data fayllarda — ranking/gamification/audiobooks "category color" sifatida (mock data fields). Bu refactor strategiya'siga ta'sir qiladi:
- **Widget-level**: AppColors.X bilan almashtirish
- **Data model**: belki retain qilish (mock data ranglari kelajakda backend'dan keladi)

## 6. `ThemeData` lokal override'lar

```
lib/features/audiobooks/presentation/screens/audio_player_screen.dart
lib/features/schedules/presentation/screens/schedules_screen.dart
```

Bu 2 screen'da lokal `Theme()` widget bilan biror narsa o'zgartiriladi (slider, dialog ranglari). Audit'da ko'rib chiqish kerak.

## 7. `GradientBackground` widget

`lib/shared/widgets/gradient_background.dart` — har screen ichida wrap. `scaffoldBackgroundColor: transparent` bilan ishlaydi. **Light theme'ga o'tishda bu widget ham qayta yoziladi** yoki butunlay olib tashlanadi.

---

## 8. Reja tomondan yangi palette (taklif)

```dart
// PRIMARY (Duolingo Green) — to'liq new
primary           = #58CC02
primaryHover      = #46A302
primaryDisabled   = #9CCC65
primaryShadow     = #46A302  // 3D button bottom

// SECONDARY (Friendly Blue) — YANGI tushuncha
secondary         = #1CB0F6
secondaryHover    = #0E96D6
secondaryShadow   = #0E96D6

// ACCENT (Sunshine Yellow) — YANGI
accent            = #FFC800
accentHover       = #E5B400
accentShadow      = #E5B400

// STATUS
warning           = #FF9600  (different shade)
warningShadow     = #CC7700
danger            = #FF4B4B  (was error)
dangerShadow      = #CC3030
success           = primary   (#58CC02)
info              = secondary (#1CB0F6)

// BACKGROUNDS (Light Mode) — YANGI
bgPrimary         = #FFFFFF
bgSurface         = #F7F7F7
bgAccent          = #FFF8E7  (soft yellow)
bgSky             = #E0F2FE  (cosmic sky)

// BACKGROUNDS (Dark Mode) — fallback
bgPrimaryDark     = #131F24
bgSurfaceDark     = #1E2D32
bgCardDark        = #2D4147

// TEXT — INVERTED (light theme)
textPrimary       = #1A2B3B  (dark navy text on white)
textSecondary     = #4A5568
textTertiary      = #94A3B8
textOnPrimary     = #FFFFFF  (white on green button)
textOnAccent      = #1A2B3B  (dark on yellow)

// DIVIDERS / BORDERS
divider           = #E2E8F0
border            = #CBD5E0

// SHADOWS
shadowLight       = #0F1A2B3B  (6% opacity)
shadowMedium      = #141A2B3B  (8% opacity)
shadowFAB         = #29FFC800  (16% accent)

// UZBEK PRIDE (use sparingly, <5%)
uzbFlagBlue       = #1EB5E5
uzbFlagRed        = #CE1126
uzbFlagGreen      = #1EAF53
```

---

## 9. ⚠️ Critical decisions for USER

### Decision A: Theme mode

Reja: `themeMode: ThemeMode.light` (default light, dark fallback).

**Trade-off:**
- Dark → Light is **drastic visual change**. Hozirgi bola foydalanuvchi dark interfaceni bilgan.
- Light mode "playful" hissi (Duolingo) — yorug', xushchaqchaq.
- Dark mode kechqurun ish uchun yaxshi (battery save, eye strain).
- Reja "light asosiy" deydi, lekin Settings'da toggle kerak.

### Decision B: GradientBackground widget

Hozir har screen `GradientBackground` bilan o'rab olinadi (dark navy gradient). Light mode'da:
- **Option 1**: GradientBackground olib tashlash → flat `bgPrimary` (white)
- **Option 2**: Yangi soft pastel gradient (bgAccent + bgSky)
- **Option 3**: Faqat dark mode'da render qilish

### Decision C: 177 hardcoded `Color()` strategy

- **Strict** (reja talabi): hammasini `AppColors.X` ga almashtirish (177 ta refactor)
- **Pragmatic**: faqat widget level ranglari (data model'dagi category ranglar saqlanadi)

### Decision D: Brand consistency Parent App bilan

Hozir Parent App ham lime green dark theme (brand identity hujjati). Child App light Duolingo green'ga o'tsa — **ikki app brand farqi paydo bo'ladi**. Parent App ham keyinroq o'zgartirilishi kerakmi?

---

## 10. Status

- [x] Step 1: Audit
- [ ] **Decision approval (waiting user)**
- [ ] Step 2: New `app_colors.dart`
- [ ] Step 3: New `app_theme.dart`
- [ ] Step 4: ~~google_fonts dependency~~ (allaqachon bor)
- [ ] Step 5: Apply theme in main.dart
- [ ] Step 6: Refactor hardcoded colors (177 ta)
- [ ] Step 7: Test + screenshot + commit

---

*Sprint UI.1 audit yakuni. Step 2 boshlashdan oldin user decisions A/B/C/D tasdig'i kerak.*
